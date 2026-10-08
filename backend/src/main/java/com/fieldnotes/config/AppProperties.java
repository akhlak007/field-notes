package com.fieldnotes.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Photos photos) {

	public record Jwt(String secret, int accessTokenMinutes, int refreshTokenDays) {
	}

	public record Photos(String dir) {
	}
}
