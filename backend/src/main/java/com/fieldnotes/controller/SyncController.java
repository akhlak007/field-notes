package com.fieldnotes.controller;

import com.fieldnotes.dto.SyncDtos.SyncPullResponse;
import com.fieldnotes.dto.SyncDtos.SyncPushRequest;
import com.fieldnotes.dto.SyncDtos.SyncPushResponse;
import com.fieldnotes.security.CurrentUser;
import com.fieldnotes.service.SyncService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

@RestController
@RequestMapping("/api/sync")
public class SyncController {

	private final SyncService syncService;

	public SyncController(SyncService syncService) {
		this.syncService = syncService;
	}

	@PostMapping("/push")
	public SyncPushResponse push(@RequestBody SyncPushRequest request) {
		return syncService.push(CurrentUser.id(), request);
	}

	@GetMapping("/pull")
	public SyncPullResponse pull(@RequestParam(required = false) Instant since) {
		return syncService.pull(CurrentUser.id(), since);
	}
}
