package com.fieldnotes.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

public final class SiteDtos {

	private SiteDtos() {
	}

	public record SiteWrite(
			@NotNull UUID customerId,
			@NotBlank @Size(max = 255) String siteName,
			@Size(max = 4000) String address,
			Instant createdAt) {
	}

	public record SiteResponse(
			UUID id,
			UUID customerId,
			String siteName,
			String address,
			Instant createdAt,
			Instant updatedAt) {
	}

	public record SiteSummary(UUID id, String siteName, String address, UUID customerId) {
	}

	public record SiteSyncRow(
			UUID id,
			UUID customerId,
			String siteName,
			String address,
			Instant createdAt,
			Instant updatedAt,
			Instant deletedAt) {
	}
}
