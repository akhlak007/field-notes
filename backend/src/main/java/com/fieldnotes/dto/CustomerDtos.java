package com.fieldnotes.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.util.UUID;

public final class CustomerDtos {

	private CustomerDtos() {
	}

	public record CustomerWrite(
			@NotBlank @Size(max = 255) String name,
			@Size(max = 4000) String contactInfo,
			Instant createdAt) {
	}

	public record CustomerResponse(
			UUID id,
			String name,
			String contactInfo,
			Instant createdAt,
			Instant updatedAt) {
	}

	public record CustomerSummary(UUID id, String name) {
	}

	public record CustomerSyncRow(
			UUID id,
			String name,
			String contactInfo,
			Instant createdAt,
			Instant updatedAt,
			Instant deletedAt) {
	}
}
