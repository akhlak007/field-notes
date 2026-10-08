package com.fieldnotes.controller;

import com.fieldnotes.dto.CustomerDtos.CustomerResponse;
import com.fieldnotes.dto.CustomerDtos.CustomerWrite;
import com.fieldnotes.security.CurrentUser;
import com.fieldnotes.service.CustomerService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/customers")
public class CustomerController {

	private final CustomerService customers;

	public CustomerController(CustomerService customers) {
		this.customers = customers;
	}

	@GetMapping
	public List<CustomerResponse> list() {
		return customers.list(CurrentUser.id());
	}

	@GetMapping("/{id}")
	public CustomerResponse get(@PathVariable UUID id) {
		return customers.get(CurrentUser.id(), id);
	}

	@PutMapping("/{id}")
	public CustomerResponse upsert(@PathVariable UUID id, @Valid @RequestBody CustomerWrite body) {
		return customers.upsert(CurrentUser.id(), id, body);
	}

	@DeleteMapping("/{id}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void delete(@PathVariable UUID id) {
		customers.delete(CurrentUser.id(), id);
	}
}
