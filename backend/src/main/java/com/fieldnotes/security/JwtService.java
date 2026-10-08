package com.fieldnotes.security;

import com.fieldnotes.config.AppProperties;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

@Service
public class JwtService {

	static final String ACCESS = "access";
	static final String REFRESH = "refresh";

	private final AppProperties properties;
	private final SecretKey key;

	public JwtService(AppProperties properties) {
		this.properties = properties;
		byte[] secret = properties.jwt().secret().getBytes(StandardCharsets.UTF_8);
		if (secret.length < 32) {
			throw new IllegalStateException("JWT_SECRET must be at least 32 bytes");
		}
		this.key = Keys.hmacShaKeyFor(secret);
	}

	public String accessToken(long userId, String email) {
		return token(userId, email, ACCESS, Instant.now().plusSeconds(properties.jwt().accessTokenMinutes() * 60L));
	}

	public String refreshToken(long userId, String email) {
		return token(userId, email, REFRESH, Instant.now().plusSeconds(properties.jwt().refreshTokenDays() * 86400L));
	}

	public long accessTtlSeconds() {
		return properties.jwt().accessTokenMinutes() * 60L;
	}

	public AuthPrincipal parseAccess(String token) {
		return parse(token, ACCESS);
	}

	public AuthPrincipal parseRefresh(String token) {
		return parse(token, REFRESH);
	}

	private String token(long userId, String email, String type, Instant expiresAt) {
		Instant now = Instant.now();
		return Jwts.builder()
				.subject(Long.toString(userId))
				.claim("email", email)
				.claim("tokenType", type)
				.issuedAt(Date.from(now))
				.expiration(Date.from(expiresAt))
				.signWith(key)
				.compact();
	}

	private AuthPrincipal parse(String token, String expectedType) {
		Claims claims = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
		if (!expectedType.equals(claims.get("tokenType", String.class))) {
			throw new io.jsonwebtoken.JwtException("Unexpected token type");
		}
		String email = claims.get("email", String.class);
		return new AuthPrincipal(Long.parseLong(claims.getSubject()), email);
	}
}
