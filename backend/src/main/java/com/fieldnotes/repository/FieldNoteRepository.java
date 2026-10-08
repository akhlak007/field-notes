package com.fieldnotes.repository;

import com.fieldnotes.entity.FieldNote;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public interface FieldNoteRepository extends JpaRepository<FieldNote, UUID> {

	List<FieldNote> findByUserIdAndUpdatedAtGreaterThanEqualOrderByUpdatedAtAsc(Long userId, Instant since);

	@Modifying(clearAutomatically = true, flushAutomatically = true)
	@Query("""
			update FieldNote n
			set n.deletedAt = :now, n.updatedAt = :now
			where n.userId = :userId and n.siteId = :siteId and n.deletedAt is null
			""")
	int softDeleteBySite(Long userId, UUID siteId, Instant now);

	@Modifying(clearAutomatically = true, flushAutomatically = true)
	@Query("""
			update FieldNote n
			set n.deletedAt = :now, n.updatedAt = :now
			where n.userId = :userId
			  and n.deletedAt is null
			  and n.siteId in (select s.id from Site s where s.userId = :userId and s.customerId = :customerId)
			""")
	int softDeleteByCustomer(Long userId, UUID customerId, Instant now);
}
