package com.fieldnotes.config;

import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;

@Component
public class ProductionSecrets {

	private final AppProperties properties;

	public ProductionSecrets(AppProperties properties) {
		this.properties = properties;
	}

	@PostConstruct
	public void verify() {
		String secret = properties.jwt().secret();
		if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
			throw new IllegalStateException("JWT_SECRET must be set and at least 32 bytes");
		}
		if (secret.contains("change-me") || secret.contains("dev-secret")) {
			throw new IllegalStateException(
					"JWT_SECRET must be a long random value; do not use a placeholder or the old development default");
		}
	}
}
