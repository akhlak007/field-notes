package com.fieldnotes.repository;

import com.fieldnotes.entity.Customer;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CustomerRepository extends JpaRepository<Customer, UUID> {

	List<Customer> findByUserIdAndDeletedAtIsNullOrderByNameAsc(Long userId);

	Optional<Customer> findByIdAndUserIdAndDeletedAtIsNull(UUID id, Long userId);

	List<Customer> findByUserIdAndUpdatedAtGreaterThanEqualOrderByUpdatedAtAsc(Long userId, Instant since);
}
