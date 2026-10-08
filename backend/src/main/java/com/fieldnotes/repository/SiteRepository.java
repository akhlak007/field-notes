package com.fieldnotes.repository;

import com.fieldnotes.entity.Site;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SiteRepository extends JpaRepository<Site, UUID> {

	List<Site> findByUserIdAndDeletedAtIsNullOrderBySiteNameAsc(Long userId);

	List<Site> findByUserIdAndCustomerIdAndDeletedAtIsNullOrderBySiteNameAsc(Long userId, UUID customerId);

	Optional<Site> findByIdAndUserIdAndDeletedAtIsNull(UUID id, Long userId);

	List<Site> findByUserIdAndUpdatedAtGreaterThanEqualOrderByUpdatedAtAsc(Long userId, Instant since);

	@Modifying(clearAutomatically = true, flushAutomatically = true)
	@Query("""
			update Site s
			set s.deletedAt = :now, s.updatedAt = :now
			where s.userId = :userId and s.customerId = :customerId and s.deletedAt is null
			""")
	int softDeleteByCustomer(Long userId, UUID customerId, Instant now);
}
