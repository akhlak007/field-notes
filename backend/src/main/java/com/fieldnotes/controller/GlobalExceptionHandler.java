package com.fieldnotes.controller;

import com.fieldnotes.dto.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

	@ExceptionHandler(ResponseStatusException.class)
	public ResponseEntity<ApiError> status(ResponseStatusException ex, HttpServletRequest request) {
		int code = ex.getStatusCode().value();
		String reason = ex.getReason() == null ? ex.getStatusCode().toString() : ex.getReason();
		return ResponseEntity.status(code).body(error(code, phrase(code), reason, request));
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	public ResponseEntity<ApiError> validation(MethodArgumentNotValidException ex, HttpServletRequest request) {
		String message = ex.getBindingResult().getFieldErrors().stream()
				.map(field -> field.getField() + " " + field.getDefaultMessage())
				.collect(Collectors.joining("; "));
		if (message.isBlank()) {
			message = "Request is invalid";
		}
		return ResponseEntity.badRequest().body(error(400, "Bad Request", message, request));
	}

	@ExceptionHandler(HttpMessageNotReadableException.class)
	public ResponseEntity<ApiError> unreadable(HttpServletRequest request) {
		return ResponseEntity.badRequest().body(error(400, "Bad Request", "Request body is invalid", request));
	}

	@ExceptionHandler(MethodArgumentTypeMismatchException.class)
	public ResponseEntity<ApiError> typeMismatch(HttpServletRequest request) {
		return ResponseEntity.badRequest().body(error(400, "Bad Request", "Request parameter is invalid", request));
	}

	@ExceptionHandler(Exception.class)
	public ResponseEntity<ApiError> unexpected(HttpServletRequest request) {
		return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
				.body(error(500, "Internal Server Error", "Unexpected error", request));
	}

	private static ApiError error(int status, String error, String message, HttpServletRequest request) {
		return new ApiError(Instant.now(), status, error, message, request.getRequestURI());
	}

	private static String phrase(int code) {
		HttpStatus status = HttpStatus.resolve(code);
		return status == null ? "Error" : status.getReasonPhrase();
	}
}
