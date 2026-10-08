package com.fieldnotes.service;

import com.fieldnotes.config.AppProperties;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.UUID;

@Component
public class PhotoStorage {

	private final Path root;

	public PhotoStorage(AppProperties properties) throws IOException {
		this.root = Path.of(properties.photos().dir()).toAbsolutePath().normalize();
		Files.createDirectories(root);
	}

	public String store(UUID noteId, MultipartFile file) {
		if (file == null || file.isEmpty()) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Photo file is required");
		}
		String extension = extensionFor(file);
		deleteExisting(noteId);
		String filename = noteId + extension;
		Path target = root.resolve(filename).normalize();
		if (!target.startsWith(root)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid photo path");
		}
		try (InputStream input = file.getInputStream()) {
			Files.copy(input, target);
		}
		catch (IOException ex) {
			throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Could not store photo");
		}
		return filename;
	}

	public Resource load(String photoUrl) {
		Path path = resolve(photoUrl);
		if (!Files.exists(path)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo not found");
		}
		return new FileSystemResource(path);
	}

	public MediaType mediaType(String photoUrl) {
		String lower = photoUrl.toLowerCase(Locale.ROOT);
		if (lower.endsWith(".png")) {
			return MediaType.IMAGE_PNG;
		}
		if (lower.endsWith(".webp")) {
			return MediaType.parseMediaType("image/webp");
		}
		return MediaType.IMAGE_JPEG;
	}

	private void deleteExisting(UUID noteId) {
		String prefix = noteId.toString();
		try (var files = Files.list(root)) {
			files.filter(path -> path.getFileName().toString().startsWith(prefix)).forEach(path -> {
				try {
					Files.deleteIfExists(path);
				}
				catch (IOException ignored) {
					// A leftover file does not block the new upload.
				}
			});
		}
		catch (IOException ignored) {
			// Directory listing failure is handled by the subsequent write.
		}
	}

	private Path resolve(String photoUrl) {
		if (photoUrl == null || photoUrl.contains("..") || photoUrl.contains("/") || photoUrl.contains("\\")) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo not found");
		}
		Path path = root.resolve(photoUrl).normalize();
		if (!path.startsWith(root)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Photo not found");
		}
		return path;
	}

	private static String extensionFor(MultipartFile file) {
		String type = file.getContentType() == null ? "" : file.getContentType().toLowerCase(Locale.ROOT);
		return switch (type) {
			case "image/jpeg", "image/jpg" -> ".jpg";
			case "image/png" -> ".png";
			case "image/webp" -> ".webp";
			default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Photo must be JPEG, PNG, or WebP");
		};
	}
}
