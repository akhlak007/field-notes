package com.fieldnotes.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "field_notes")
public class FieldNote {

	@Id
	private UUID id;

	@Column(name = "user_id", nullable = false)
	private Long userId;

	@Column(name = "site_id", nullable = false)
	private UUID siteId;

	@Column(nullable = false, length = 255)
	private String title;

	@Column
	private String description;

	@Column
	private Double latitude;

	@Column
	private Double longitude;

	@Column(name = "noted_at", nullable = false)
	private Instant notedAt;

	@Enumerated(EnumType.STRING)
	@Column(nullable = false, length = 32)
	private NoteStatus status;

	@Column(name = "photo_url")
	private String photoUrl;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	@Column(name = "deleted_at")
	private Instant deletedAt;

	public UUID getId() {
		return id;
	}

	public void setId(UUID id) {
		this.id = id;
	}

	public Long getUserId() {
		return userId;
	}

	public void setUserId(Long userId) {
		this.userId = userId;
	}

	public UUID getSiteId() {
		return siteId;
	}

	public void setSiteId(UUID siteId) {
		this.siteId = siteId;
	}

	public String getTitle() {
		return title;
	}

	public void setTitle(String title) {
		this.title = title;
	}

	public String getDescription() {
		return description;
	}

	public void setDescription(String description) {
		this.description = description;
	}

	public Double getLatitude() {
		return latitude;
	}

	public void setLatitude(Double latitude) {
		this.latitude = latitude;
	}

	public Double getLongitude() {
		return longitude;
	}

	public void setLongitude(Double longitude) {
		this.longitude = longitude;
	}

	public Instant getNotedAt() {
		return notedAt;
	}

	public void setNotedAt(Instant notedAt) {
		this.notedAt = notedAt;
	}

	public NoteStatus getStatus() {
		return status;
	}

	public void setStatus(NoteStatus status) {
		this.status = status;
	}

	public String getPhotoUrl() {
		return photoUrl;
	}

	public void setPhotoUrl(String photoUrl) {
		this.photoUrl = photoUrl;
	}

	public Instant getCreatedAt() {
		return createdAt;
	}

	public void setCreatedAt(Instant createdAt) {
		this.createdAt = createdAt;
	}

	public Instant getUpdatedAt() {
		return updatedAt;
	}

	public void setUpdatedAt(Instant updatedAt) {
		this.updatedAt = updatedAt;
	}

	public Instant getDeletedAt() {
		return deletedAt;
	}

	public void setDeletedAt(Instant deletedAt) {
		this.deletedAt = deletedAt;
	}
}
