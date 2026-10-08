package com.fieldnotes.service;

import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

public final class Texts {

	private Texts() {
	}

	public static String required(String value, String field, int max) {
		if (value == null || value.isBlank()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " is required");
		}
		String trimmed = value.trim();
		if (trimmed.length() > max) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, field + " is too long");
		}
		return trimmed;
	}

	public static String optional(String value, int max) {
		if (value == null) {
			return null;
		}
		String trimmed = value.trim();
		if (trimmed.isEmpty()) {
			return null;
		}
		if (trimmed.length() > max) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Value is too long");
		}
		return trimmed;
	}
}
