package com.fieldnotes.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@Component
public class SyncTransactionLock {

	static final long LOCK_KEY = 0x4649454c444e4f54L;

	private final JdbcTemplate jdbc;

	public SyncTransactionLock(JdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public void acquire() {
		if (!TransactionSynchronizationManager.isActualTransactionActive()) {
			throw new IllegalStateException("The sync transaction lock requires an active transaction");
		}
		jdbc.queryForObject("select pg_advisory_xact_lock(?)", Object.class, LOCK_KEY);
	}
}
