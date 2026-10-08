package com.fieldnotes.controller;

import com.fieldnotes.dto.SiteDtos.SiteResponse;
import com.fieldnotes.dto.SiteDtos.SiteWrite;
import com.fieldnotes.security.CurrentUser;
import com.fieldnotes.service.SiteService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/sites")
public class SiteController {

	private final SiteService sites;

	public SiteController(SiteService sites) {
		this.sites = sites;
	}

	@GetMapping
	public List<SiteResponse> list(@RequestParam(required = false) UUID customerId) {
		return sites.list(CurrentUser.id(), customerId);
	}

	@GetMapping("/{id}")
	public SiteResponse get(@PathVariable UUID id) {
		return sites.get(CurrentUser.id(), id);
	}

	@PutMapping("/{id}")
	public SiteResponse upsert(@PathVariable UUID id, @Valid @RequestBody SiteWrite body) {
		return sites.upsert(CurrentUser.id(), id, body);
	}

	@DeleteMapping("/{id}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void delete(@PathVariable UUID id) {
		sites.delete(CurrentUser.id(), id);
	}
}
