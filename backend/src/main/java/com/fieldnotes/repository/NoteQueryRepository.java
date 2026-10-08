package com.fieldnotes.repository;

import com.fieldnotes.dto.CustomerDtos.CustomerSummary;
import com.fieldnotes.dto.NoteDtos.NoteResponse;
import com.fieldnotes.dto.SiteDtos.SiteSummary;
import com.fieldnotes.entity.Customer;
import com.fieldnotes.entity.FieldNote;
import com.fieldnotes.entity.NoteStatus;
import com.fieldnotes.entity.Site;
import jakarta.persistence.EntityManager;
import jakarta.persistence.TypedQuery;
import org.springframework.stereotype.Repository;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@Repository
public class NoteQueryRepository {

	private final EntityManager entityManager;

	public NoteQueryRepository(EntityManager entityManager) {
		this.entityManager = entityManager;
	}

	public List<NoteResponse> search(long userId, NoteStatus status, UUID siteId, String query) {
		StringBuilder jpql = new StringBuilder("""
				select n, s, c
				from FieldNote n
				join Site s on s.id = n.siteId
				join Customer c on c.id = s.customerId
				where n.userId = :userId
				  and s.userId = :userId
				  and c.userId = :userId
				  and n.deletedAt is null
				  and s.deletedAt is null
				  and c.deletedAt is null
				""");
		Map<String, Object> params = new HashMap<>();
		params.put("userId", userId);
		if (status != null) {
			jpql.append(" and n.status = :status");
			params.put("status", status);
		}
		if (siteId != null) {
			jpql.append(" and n.siteId = :siteId");
			params.put("siteId", siteId);
		}
		if (query != null && !query.isBlank()) {
			jpql.append("""
					 and (
					   lower(n.title) like :q escape '!'
					   or lower(coalesce(n.description, '')) like :q escape '!'
					   or lower(s.siteName) like :q escape '!'
					   or lower(c.name) like :q escape '!'
					 )
					""");
			params.put("q", likePattern(query));
		}
		jpql.append(" order by n.notedAt desc");
		TypedQuery<Object[]> typed = entityManager.createQuery(jpql.toString(), Object[].class);
		params.forEach(typed::setParameter);
		return typed.getResultList().stream().map(NoteQueryRepository::toResponse).toList();
	}

	public Optional<NoteResponse> findActive(long userId, UUID id) {
		List<Object[]> rows = entityManager.createQuery("""
				select n, s, c
				from FieldNote n
				join Site s on s.id = n.siteId
				join Customer c on c.id = s.customerId
				where n.userId = :userId
				  and s.userId = :userId
				  and c.userId = :userId
				  and n.id = :id
				  and n.deletedAt is null
				  and s.deletedAt is null
				  and c.deletedAt is null
				""", Object[].class)
				.setParameter("userId", userId)
				.setParameter("id", id)
				.getResultList();
		return rows.stream().findFirst().map(NoteQueryRepository::toResponse);
	}

	private static NoteResponse toResponse(Object[] row) {
		FieldNote note = (FieldNote) row[0];
		Site site = (Site) row[1];
		Customer customer = (Customer) row[2];
		return new NoteResponse(
				note.getId(),
				note.getSiteId(),
				note.getTitle(),
				note.getDescription(),
				note.getLatitude(),
				note.getLongitude(),
				note.getNotedAt(),
				note.getStatus(),
				note.getPhotoUrl(),
				note.getCreatedAt(),
				note.getUpdatedAt(),
				new SiteSummary(site.getId(), site.getSiteName(), site.getAddress(), site.getCustomerId()),
				new CustomerSummary(customer.getId(), customer.getName()));
	}

	static String likePattern(String query) {
		String escaped = query.trim().toLowerCase()
				.replace("!", "!!")
				.replace("%", "!%")
				.replace("_", "!_");
		return "%" + escaped + "%";
	}
}
