package com.fieldnotes.config;

import jakarta.annotation.PostConstruct;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.util.Arrays;

@Component
public class ProductionSecrets {

	private final AppProperties properties;
	private final Environment environment;

	public ProductionSecrets(AppProperties properties, Environment environment) {
		this.properties = properties;
		this.environment = environment;
	}

	@PostConstruct
	public void verify() {
		String secret = properties.jwt().secret();
		if (secret == null || secret.getBytes(StandardCharsets.UTF_8).length < 32) {
			throw new IllegalStateException("JWT_SECRET must be set and at least 32 bytes");
		}
		boolean prod = Arrays.stream(environment.getActiveProfiles()).anyMatch("prod"::equalsIgnoreCase);
		if (prod && (secret.contains("change-me") || secret.contains("dev-secret"))) {
			throw new IllegalStateException(
					"JWT_SECRET must be a long random value in production; do not use the local default");
		}
	}
}
