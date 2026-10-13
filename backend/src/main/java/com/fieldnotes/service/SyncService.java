package com.fieldnotes.service;

import com.fieldnotes.dto.CustomerDtos.CustomerWrite;
import com.fieldnotes.dto.NoteDtos.NoteWrite;
import com.fieldnotes.dto.SiteDtos.SiteWrite;
import com.fieldnotes.dto.SyncDtos.CustomerPushItem;
import com.fieldnotes.dto.SyncDtos.NotePushItem;
import com.fieldnotes.dto.SyncDtos.SitePushItem;
import com.fieldnotes.dto.SyncDtos.SyncItemResult;
import com.fieldnotes.dto.SyncDtos.SyncPullResponse;
import com.fieldnotes.dto.SyncDtos.SyncPushRequest;
import com.fieldnotes.dto.SyncDtos.SyncPushResponse;
import com.fieldnotes.entity.Customer;
import com.fieldnotes.entity.FieldNote;
import com.fieldnotes.entity.Site;
import com.fieldnotes.repository.CustomerRepository;
import com.fieldnotes.repository.FieldNoteRepository;
import com.fieldnotes.repository.SiteRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class SyncService {

	private final TransactionTemplate tx;
	private final CustomerRepository customers;
	private final SiteRepository sites;
	private final FieldNoteRepository notes;
	private final CustomerService customerService;
	private final SiteService siteService;
	private final NoteService noteService;
	private final SyncTransactionLock syncLock;

	public SyncService(
			PlatformTransactionManager transactionManager,
			CustomerRepository customers,
			SiteRepository sites,
			FieldNoteRepository notes,
			CustomerService customerService,
			SiteService siteService,
			NoteService noteService,
			SyncTransactionLock syncLock) {
		this.tx = new TransactionTemplate(transactionManager);
		this.tx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
		this.customers = customers;
		this.sites = sites;
		this.notes = notes;
		this.customerService = customerService;
		this.siteService = siteService;
		this.noteService = noteService;
		this.syncLock = syncLock;
	}

	public SyncPushResponse push(long userId, SyncPushRequest request) {
		Instant serverTime = Instant.now();
		List<SyncItemResult> customerResults = new ArrayList<>();
		for (CustomerPushItem item : request.getCustomers()) {
			customerResults.add(apply(item == null ? null : item.id(), () -> applyCustomer(userId, item)));
		}
		List<SyncItemResult> siteResults = new ArrayList<>();
		for (SitePushItem item : request.getSites()) {
			siteResults.add(apply(item == null ? null : item.id(), () -> applySite(userId, item)));
		}
		List<SyncItemResult> noteResults = new ArrayList<>();
		for (NotePushItem item : request.getNotes()) {
			noteResults.add(apply(item == null ? null : item.id(), () -> applyNote(userId, item)));
		}
		return new SyncPushResponse(serverTime, customerResults, siteResults, noteResults);
	}

	@Transactional
	public SyncPullResponse pull(long userId, Instant since) {
		syncLock.acquire();
		Instant cursor = since == null ? Instant.EPOCH : since;
		Instant serverTime = Instant.now();
		return new SyncPullResponse(
				serverTime,
				customerService.changedSince(userId, cursor),
				siteService.changedSince(userId, cursor),
				noteService.changedSince(userId, cursor));
	}

	private SyncItemResult apply(UUID id, ItemAction action) {
		if (id == null) {
			return SyncItemResult.error(null, "Id is required");
		}
		try {
			return tx.execute(status -> action.run());
		}
		catch (ResponseStatusException ex) {
			String message = ex.getReason() == null ? "Request failed" : ex.getReason();
			return SyncItemResult.error(id, message);
		}
		catch (RuntimeException ex) {
			return SyncItemResult.error(id, "Could not apply change");
		}
	}

	private SyncItemResult applyCustomer(long userId, CustomerPushItem item) {
		Customer existing = customers.findById(item.id()).orElse(null);
		if (existing != null && !existing.getUserId().equals(userId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Customer not found");
		}
		if (item.deleted()) {
			if (existing == null || existing.getDeletedAt() != null) {
				return SyncItemResult.applied(item.id(), existing == null ? null : existing.getUpdatedAt());
			}
			customerService.delete(userId, item.id());
			return SyncItemResult.applied(item.id(), customers.findById(item.id()).map(Customer::getUpdatedAt).orElse(null));
		}
		var saved = customerService.upsert(userId, item.id(), new CustomerWrite(item.name(), item.contactInfo(), item.createdAt()));
		return SyncItemResult.applied(item.id(), saved.updatedAt());
	}

	private SyncItemResult applySite(long userId, SitePushItem item) {
		Site existing = sites.findById(item.id()).orElse(null);
		if (existing != null && !existing.getUserId().equals(userId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Site not found");
		}
		if (item.deleted()) {
			if (existing == null || existing.getDeletedAt() != null) {
				return SyncItemResult.applied(item.id(), existing == null ? null : existing.getUpdatedAt());
			}
			siteService.delete(userId, item.id());
			return SyncItemResult.applied(item.id(), sites.findById(item.id()).map(Site::getUpdatedAt).orElse(null));
		}
		var saved = siteService.upsert(
				userId,
				item.id(),
				new SiteWrite(item.customerId(), item.siteName(), item.address(), item.createdAt()));
		return SyncItemResult.applied(item.id(), saved.updatedAt());
	}

	private SyncItemResult applyNote(long userId, NotePushItem item) {
		FieldNote existing = notes.findById(item.id()).orElse(null);
		if (existing != null && !existing.getUserId().equals(userId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Note not found");
		}
		if (item.deleted()) {
			if (existing == null || existing.getDeletedAt() != null) {
				return SyncItemResult.applied(item.id(), existing == null ? null : existing.getUpdatedAt());
			}
			noteService.delete(userId, item.id());
			return SyncItemResult.applied(item.id(), notes.findById(item.id()).map(FieldNote::getUpdatedAt).orElse(null));
		}
		var saved = noteService.upsert(userId, item.id(), new NoteWrite(
				item.siteId(),
				item.title(),
				item.description(),
				item.latitude(),
				item.longitude(),
				item.notedAt(),
				item.status(),
				item.createdAt()));
		return SyncItemResult.applied(item.id(), saved.updatedAt());
	}

	@FunctionalInterface
	private interface ItemAction {
		SyncItemResult run();
	}
}
