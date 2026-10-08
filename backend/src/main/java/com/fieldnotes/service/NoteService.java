package com.fieldnotes.service;

import com.fieldnotes.dto.NoteDtos.NoteResponse;
import com.fieldnotes.dto.NoteDtos.NoteSyncRow;
import com.fieldnotes.dto.NoteDtos.NoteWrite;
import com.fieldnotes.entity.FieldNote;
import com.fieldnotes.entity.NoteStatus;
import com.fieldnotes.repository.FieldNoteRepository;
import com.fieldnotes.repository.NoteQueryRepository;
import com.fieldnotes.repository.SiteRepository;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class NoteService {

	private final FieldNoteRepository notes;
	private final NoteQueryRepository queries;
	private final SiteRepository sites;
	private final PhotoStorage photos;

	public NoteService(
			FieldNoteRepository notes,
			NoteQueryRepository queries,
			SiteRepository sites,
			PhotoStorage photos) {
		this.notes = notes;
		this.queries = queries;
		this.sites = sites;
		this.photos = photos;
	}

	@Transactional(readOnly = true)
	public List<NoteResponse> list(long userId, NoteStatus status, UUID siteId, String query) {
		return queries.search(userId, status, siteId, query).stream().map(this::withPublicPhoto).toList();
	}

	@Transactional(readOnly = true)
	public NoteResponse get(long userId, UUID id) {
		return withPublicPhoto(queries.findActive(userId, id)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Note not found")));
	}

	@Transactional
	public NoteResponse upsert(long userId, UUID id, NoteWrite write) {
		requireSite(userId, write.siteId());
		validateLocation(write.latitude(), write.longitude());
		Instant now = Instant.now();
		FieldNote existing = notes.findById(id).orElse(null);
		if (existing != null && !existing.getUserId().equals(userId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Note not found");
		}
		FieldNote note = existing == null ? new FieldNote() : existing;
		if (existing == null) {
			note.setId(id);
			note.setUserId(userId);
			note.setCreatedAt(write.createdAt() != null ? write.createdAt() : now);
		}
		note.setSiteId(write.siteId());
		note.setTitle(Texts.required(write.title(), "Title", 255));
		note.setDescription(Texts.optional(write.description(), 8000));
		note.setLatitude(write.latitude());
		note.setLongitude(write.longitude());
		note.setNotedAt(write.notedAt());
		note.setStatus(write.status());
		note.setUpdatedAt(now);
		note.setDeletedAt(null);
		notes.save(note);
		return get(userId, id);
	}

	@Transactional
	public void delete(long userId, UUID id) {
		FieldNote note = notes.findById(id)
				.filter(found -> found.getUserId().equals(userId) && found.getDeletedAt() == null)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Note not found"));
		Instant now = Instant.now();
		note.setDeletedAt(now);
		note.setUpdatedAt(now);
		notes.save(note);
	}

	@Transactional
	public NoteResponse storePhoto(long userId, UUID id, MultipartFile file) {
		FieldNote note = notes.findById(id)
				.filter(found -> found.getUserId().equals(userId) && found.getDeletedAt() == null)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Note not found"));
		String stored = photos.store(id, file);
		note.setPhotoUrl(stored);
		note.setUpdatedAt(Instant.now());
		notes.save(note);
		return get(userId, id);
	}

	@Transactional(readOnly = true)
	public StoredPhoto loadPhoto(long userId, UUID id) {
		FieldNote note = notes.findById(id)
				.filter(found -> found.getUserId().equals(userId) && found.getDeletedAt() == null)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Note not found"));
		if (note.getPhotoUrl() == null) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo not found");
		}
		return new StoredPhoto(photos.load(note.getPhotoUrl()), photos.mediaType(note.getPhotoUrl()));
	}

	@Transactional(readOnly = true)
	public List<NoteSyncRow> changedSince(long userId, Instant since) {
		return notes.findByUserIdAndUpdatedAtGreaterThanEqualOrderByUpdatedAtAsc(userId, since).stream()
				.map(this::toSync)
				.toList();
	}

	private void requireSite(long userId, UUID siteId) {
		sites.findByIdAndUserIdAndDeletedAtIsNull(siteId, userId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Site not found"));
	}

	private void validateLocation(Double latitude, Double longitude) {
		if (latitude == null && longitude == null) {
			return;
		}
		if (latitude == null || longitude == null) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Latitude and longitude must both be set");
		}
		if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Location is out of range");
		}
	}

	private NoteResponse withPublicPhoto(NoteResponse row) {
		if (row.photoUrl() == null) {
			return row;
		}
		return new NoteResponse(
				row.id(),
				row.siteId(),
				row.title(),
				row.description(),
				row.latitude(),
				row.longitude(),
				row.notedAt(),
				row.status(),
				"/api/notes/" + row.id() + "/photo",
				row.createdAt(),
				row.updatedAt(),
				row.site(),
				row.customer());
	}

	private NoteSyncRow toSync(FieldNote note) {
		return new NoteSyncRow(
				note.getId(),
				note.getSiteId(),
				note.getTitle(),
				note.getDescription(),
				note.getLatitude(),
				note.getLongitude(),
				note.getNotedAt(),
				note.getStatus(),
				note.getPhotoUrl() == null ? null : "/api/notes/" + note.getId() + "/photo",
				note.getCreatedAt(),
				note.getUpdatedAt(),
				note.getDeletedAt());
	}

	public record StoredPhoto(Resource resource, MediaType mediaType) {
	}
}
