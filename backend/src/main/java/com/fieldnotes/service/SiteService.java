package com.fieldnotes.service;

import com.fieldnotes.dto.SiteDtos.SiteResponse;
import com.fieldnotes.dto.SiteDtos.SiteSyncRow;
import com.fieldnotes.dto.SiteDtos.SiteWrite;
import com.fieldnotes.entity.Site;
import com.fieldnotes.repository.CustomerRepository;
import com.fieldnotes.repository.FieldNoteRepository;
import com.fieldnotes.repository.SiteRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class SiteService {

	private final SiteRepository sites;
	private final CustomerRepository customers;
	private final FieldNoteRepository notes;
	private final SyncTransactionLock syncLock;

	public SiteService(
			SiteRepository sites,
			CustomerRepository customers,
			FieldNoteRepository notes,
			SyncTransactionLock syncLock) {
		this.sites = sites;
		this.customers = customers;
		this.notes = notes;
		this.syncLock = syncLock;
	}

	@Transactional(readOnly = true)
	public List<SiteResponse> list(long userId, UUID customerId) {
		var rows = customerId == null
				? sites.findByUserIdAndDeletedAtIsNullOrderBySiteNameAsc(userId)
				: sites.findByUserIdAndCustomerIdAndDeletedAtIsNullOrderBySiteNameAsc(userId, customerId);
		return rows.stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public SiteResponse get(long userId, UUID id) {
		return toResponse(active(userId, id));
	}

	@Transactional
	public SiteResponse upsert(long userId, UUID id, SiteWrite write) {
		syncLock.acquire();
		requireCustomer(userId, write.customerId());
		Instant now = Instant.now();
		Site existing = sites.findById(id).orElse(null);
		if (existing != null && !existing.getUserId().equals(userId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Site not found");
		}
		Site site = existing == null ? new Site() : existing;
		if (existing == null) {
			site.setId(id);
			site.setUserId(userId);
			site.setCreatedAt(write.createdAt() != null ? write.createdAt() : now);
		}
		site.setCustomerId(write.customerId());
		site.setSiteName(Texts.required(write.siteName(), "Site name", 255));
		site.setAddress(Texts.optional(write.address(), 4000));
		site.setUpdatedAt(now);
		site.setDeletedAt(null);
		return toResponse(sites.save(site));
	}

	@Transactional
	public void delete(long userId, UUID id) {
		syncLock.acquire();
		Site site = active(userId, id);
		Instant now = Instant.now();
		notes.softDeleteBySite(userId, id, now);
		site.setDeletedAt(now);
		site.setUpdatedAt(now);
		sites.save(site);
	}

	@Transactional(readOnly = true)
	public List<SiteSyncRow> changedSince(long userId, Instant since) {
		return sites.findByUserIdAndUpdatedAtGreaterThanEqualOrderByUpdatedAtAsc(userId, since).stream()
				.map(this::toSync)
				.toList();
	}

	private void requireCustomer(long userId, UUID customerId) {
		customers.findByIdAndUserIdAndDeletedAtIsNull(customerId, userId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Customer not found"));
	}

	private Site active(long userId, UUID id) {
		return sites.findByIdAndUserIdAndDeletedAtIsNull(id, userId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Site not found"));
	}

	private SiteResponse toResponse(Site site) {
		return new SiteResponse(
				site.getId(),
				site.getCustomerId(),
				site.getSiteName(),
				site.getAddress(),
				site.getCreatedAt(),
				site.getUpdatedAt());
	}

	private SiteSyncRow toSync(Site site) {
		return new SiteSyncRow(
				site.getId(),
				site.getCustomerId(),
				site.getSiteName(),
				site.getAddress(),
				site.getCreatedAt(),
				site.getUpdatedAt(),
				site.getDeletedAt());
	}
}
