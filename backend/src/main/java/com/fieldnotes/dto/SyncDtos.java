package com.fieldnotes.dto;

import com.fieldnotes.entity.NoteStatus;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

public final class SyncDtos {

	private SyncDtos() {
	}

	public static final class SyncPushRequest {
		private List<CustomerPushItem> customers = new ArrayList<>();
		private List<SitePushItem> sites = new ArrayList<>();
		private List<NotePushItem> notes = new ArrayList<>();

		public List<CustomerPushItem> getCustomers() {
			return customers == null ? List.of() : customers;
		}

		public void setCustomers(List<CustomerPushItem> customers) {
			this.customers = customers;
		}

		public List<SitePushItem> getSites() {
			return sites == null ? List.of() : sites;
		}

		public void setSites(List<SitePushItem> sites) {
			this.sites = sites;
		}

		public List<NotePushItem> getNotes() {
			return notes == null ? List.of() : notes;
		}

		public void setNotes(List<NotePushItem> notes) {
			this.notes = notes;
		}
	}

	public record CustomerPushItem(UUID id, String name, String contactInfo, Instant createdAt, boolean deleted) {
	}

	public record SitePushItem(
			UUID id,
			UUID customerId,
			String siteName,
			String address,
			Instant createdAt,
			boolean deleted) {
	}

	public record NotePushItem(
			UUID id,
			UUID siteId,
			String title,
			String description,
			Double latitude,
			Double longitude,
			Instant notedAt,
			NoteStatus status,
			Instant createdAt,
			boolean deleted) {
	}

	public record SyncItemResult(UUID id, String status, String error, Instant updatedAt) {
		public static SyncItemResult applied(UUID id, Instant updatedAt) {
			return new SyncItemResult(id, "APPLIED", null, updatedAt);
		}

		public static SyncItemResult error(UUID id, String error) {
			return new SyncItemResult(id, "ERROR", error, null);
		}
	}

	public record SyncPushResponse(
			Instant serverTime,
			List<SyncItemResult> customers,
			List<SyncItemResult> sites,
			List<SyncItemResult> notes) {
	}

	public record SyncPullResponse(
			Instant serverTime,
			List<CustomerDtos.CustomerSyncRow> customers,
			List<SiteDtos.SiteSyncRow> sites,
			List<NoteDtos.NoteSyncRow> notes) {
	}
}
