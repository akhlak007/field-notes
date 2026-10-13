package com.fieldnotes.service;

import com.fieldnotes.dto.CustomerDtos.CustomerResponse;
import com.fieldnotes.dto.CustomerDtos.CustomerSyncRow;
import com.fieldnotes.dto.CustomerDtos.CustomerWrite;
import com.fieldnotes.entity.Customer;
import com.fieldnotes.repository.CustomerRepository;
import com.fieldnotes.repository.FieldNoteRepository;
import com.fieldnotes.repository.SiteRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class CustomerService {

	private final CustomerRepository customers;
	private final SiteRepository sites;
	private final FieldNoteRepository notes;
	private final SyncTransactionLock syncLock;

	public CustomerService(
			CustomerRepository customers,
			SiteRepository sites,
			FieldNoteRepository notes,
			SyncTransactionLock syncLock) {
		this.customers = customers;
		this.sites = sites;
		this.notes = notes;
		this.syncLock = syncLock;
	}

	@Transactional(readOnly = true)
	public List<CustomerResponse> list(long userId) {
		return customers.findByUserIdAndDeletedAtIsNullOrderByNameAsc(userId).stream().map(this::toResponse).toList();
	}

	@Transactional(readOnly = true)
	public CustomerResponse get(long userId, UUID id) {
		return toResponse(active(userId, id));
	}

	@Transactional
	public CustomerResponse upsert(long userId, UUID id, CustomerWrite write) {
		syncLock.acquire();
		Instant now = Instant.now();
		Customer existing = customers.findById(id).orElse(null);
		if (existing != null && !existing.getUserId().equals(userId)) {
			throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Customer not found");
		}
		Customer customer = existing == null ? new Customer() : existing;
		if (existing == null) {
			customer.setId(id);
			customer.setUserId(userId);
			customer.setCreatedAt(write.createdAt() != null ? write.createdAt() : now);
		}
		customer.setName(Texts.required(write.name(), "Name", 255));
		customer.setContactInfo(Texts.optional(write.contactInfo(), 4000));
		customer.setUpdatedAt(now);
		customer.setDeletedAt(null);
		return toResponse(customers.save(customer));
	}

	@Transactional
	public void delete(long userId, UUID id) {
		syncLock.acquire();
		Customer customer = active(userId, id);
		Instant now = Instant.now();
		notes.softDeleteByCustomer(userId, id, now);
		sites.softDeleteByCustomer(userId, id, now);
		customer.setDeletedAt(now);
		customer.setUpdatedAt(now);
		customers.save(customer);
	}

	@Transactional(readOnly = true)
	public List<CustomerSyncRow> changedSince(long userId, Instant since) {
		return customers.findByUserIdAndUpdatedAtGreaterThanEqualOrderByUpdatedAtAsc(userId, since).stream()
				.map(this::toSync)
				.toList();
	}

	private Customer active(long userId, UUID id) {
		return customers.findByIdAndUserIdAndDeletedAtIsNull(id, userId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Customer not found"));
	}

	private CustomerResponse toResponse(Customer customer) {
		return new CustomerResponse(
				customer.getId(),
				customer.getName(),
				customer.getContactInfo(),
				customer.getCreatedAt(),
				customer.getUpdatedAt());
	}

	private CustomerSyncRow toSync(Customer customer) {
		return new CustomerSyncRow(
				customer.getId(),
				customer.getName(),
				customer.getContactInfo(),
				customer.getCreatedAt(),
				customer.getUpdatedAt(),
				customer.getDeletedAt());
	}
}
