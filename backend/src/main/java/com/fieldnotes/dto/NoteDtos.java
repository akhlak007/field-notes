package com.fieldnotes.dto;

import com.fieldnotes.entity.NoteStatus;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

public final class NoteDtos {

	private NoteDtos() {
	}

	public record NoteWrite(
			@NotNull UUID siteId,
			@NotBlank @Size(max = 255) String title,
			@Size(max = 8000) String description,
			Double latitude,
			Double longitude,
			@NotNull Instant notedAt,
			@NotNull NoteStatus status,
			Instant createdAt) {
	}

	public record NoteResponse(
			UUID id,
			UUID siteId,
			String title,
			String description,
			Double latitude,
			Double longitude,
			Instant notedAt,
			NoteStatus status,
			String photoUrl,
			Instant createdAt,
			Instant updatedAt,
			SiteDtos.SiteSummary site,
			CustomerDtos.CustomerSummary customer) {
	}

	public record NoteSyncRow(
			UUID id,
			UUID siteId,
			String title,
			String description,
			Double latitude,
			Double longitude,
			Instant notedAt,
			NoteStatus status,
			String photoUrl,
			Instant createdAt,
			Instant updatedAt,
			Instant deletedAt) {
	}
}
