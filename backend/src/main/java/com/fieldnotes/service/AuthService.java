package com.fieldnotes.service;

import com.fieldnotes.dto.AuthDtos.LoginRequest;
import com.fieldnotes.dto.AuthDtos.RefreshRequest;
import com.fieldnotes.dto.AuthDtos.RegisterRequest;
import com.fieldnotes.dto.AuthDtos.RegisterResponse;
import com.fieldnotes.dto.AuthDtos.TokenResponse;
import com.fieldnotes.entity.AppUser;
import com.fieldnotes.repository.AppUserRepository;
import com.fieldnotes.security.AuthPrincipal;
import com.fieldnotes.security.JwtService;
import io.jsonwebtoken.JwtException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;

@Service
public class AuthService {

	private final AppUserRepository users;
	private final PasswordEncoder passwordEncoder;
	private final JwtService jwtService;

	public AuthService(AppUserRepository users, PasswordEncoder passwordEncoder, JwtService jwtService) {
		this.users = users;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
	}

	@Transactional
	public RegisterResponse register(RegisterRequest request) {
		String email = request.email().trim().toLowerCase();
		if (users.existsByEmail(email)) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "Email is already registered");
		}
		AppUser user = new AppUser();
		user.setEmail(email);
		user.setPasswordHash(passwordEncoder.encode(request.password()));
		user.setCreatedAt(Instant.now());
		users.save(user);
		return new RegisterResponse(user.getId(), user.getEmail());
	}

	@Transactional(readOnly = true)
	public TokenResponse login(LoginRequest request) {
		String email = request.email().trim().toLowerCase();
		AppUser user = users.findByEmail(email)
				.filter(found -> passwordEncoder.matches(request.password(), found.getPasswordHash()))
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password"));
		return tokens(user);
	}

	public TokenResponse refresh(RefreshRequest request) {
		try {
			AuthPrincipal principal = jwtService.parseRefresh(request.refreshToken());
			AppUser user = users.findById(principal.id())
					.orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid refresh token"));
			return tokens(user);
		}
		catch (JwtException | IllegalArgumentException ex) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid refresh token");
		}
	}

	private TokenResponse tokens(AppUser user) {
		return new TokenResponse(
				jwtService.accessToken(user.getId(), user.getEmail()),
				jwtService.refreshToken(user.getId(), user.getEmail()),
				jwtService.accessTtlSeconds());
	}
}
