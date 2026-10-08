package com.fieldnotes.controller;

import com.fieldnotes.dto.NoteDtos.NoteResponse;
import com.fieldnotes.dto.NoteDtos.NoteWrite;
import com.fieldnotes.entity.NoteStatus;
import com.fieldnotes.security.CurrentUser;
import com.fieldnotes.service.NoteService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/notes")
public class NoteController {

	private final NoteService notes;

	public NoteController(NoteService notes) {
		this.notes = notes;
	}

	@GetMapping
	public List<NoteResponse> list(
			@RequestParam(required = false) NoteStatus status,
			@RequestParam(required = false) UUID siteId,
			@RequestParam(required = false) String q) {
		return notes.list(CurrentUser.id(), status, siteId, q);
	}

	@GetMapping("/{id}")
	public NoteResponse get(@PathVariable UUID id) {
		return notes.get(CurrentUser.id(), id);
	}

	@PutMapping("/{id}")
	public NoteResponse upsert(@PathVariable UUID id, @Valid @RequestBody NoteWrite body) {
		return notes.upsert(CurrentUser.id(), id, body);
	}

	@DeleteMapping("/{id}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void delete(@PathVariable UUID id) {
		notes.delete(CurrentUser.id(), id);
	}

	@PostMapping(value = "/{id}/photo", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
	public NoteResponse uploadPhoto(@PathVariable UUID id, @RequestParam("file") MultipartFile file) {
		return notes.storePhoto(CurrentUser.id(), id, file);
	}

	@GetMapping("/{id}/photo")
	public ResponseEntity<org.springframework.core.io.Resource> downloadPhoto(@PathVariable UUID id) {
		var photo = notes.loadPhoto(CurrentUser.id(), id);
		return ResponseEntity.ok().contentType(photo.mediaType()).body(photo.resource());
	}
}
