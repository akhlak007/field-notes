package com.fieldnotes;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.util.LinkedMultiValueMap;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.Instant;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
class FieldNotesApiTest {

	@Container
	static final PostgreSQLContainer<?> POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine");

	@DynamicPropertySource
	static void properties(DynamicPropertyRegistry registry) {
		registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
		registry.add("spring.datasource.username", POSTGRES::getUsername);
		registry.add("spring.datasource.password", POSTGRES::getPassword);
		registry.add("app.jwt.secret", () -> "field-notes-test-secret-key-32bytes-min");
		registry.add("app.photos.dir", () -> System.getProperty("java.io.tmpdir") + "/field-notes-photos-" + UUID.randomUUID());
	}

	@Autowired
	TestRestTemplate rest;

	@Autowired
	ObjectMapper objectMapper;

	@Test
	void healthIsPublic() {
		ResponseEntity<JsonNode> health = rest.getForEntity("/api/health", JsonNode.class);
		assertThat(health.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(health.getBody().get("status").asText()).isEqualTo("UP");
		ResponseEntity<JsonNode> actuator = rest.getForEntity("/actuator/health", JsonNode.class);
		assertThat(actuator.getStatusCode()).isEqualTo(HttpStatus.OK);
	}

	@Test
	void registerLoginAndRefresh() throws Exception {
		String email = email();
		ResponseEntity<String> created = rest.postForEntity("/api/auth/register",
				Map.of("email", email, "password", "password123"), String.class);
		assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);

		ResponseEntity<String> duplicate = rest.postForEntity("/api/auth/register",
				Map.of("email", email, "password", "password123"), String.class);
		assertThat(duplicate.getStatusCode()).isEqualTo(HttpStatus.CONFLICT);

		JsonNode tokens = login(email);
		assertThat(tokens.get("accessToken").asText()).isNotBlank();
		assertThat(tokens.get("refreshToken").asText()).isNotBlank();
		assertThat(tokens.get("expiresIn").asLong()).isPositive();

		ResponseEntity<JsonNode> refreshed = rest.postForEntity("/api/auth/refresh",
				Map.of("refreshToken", tokens.get("refreshToken").asText()), JsonNode.class);
		assertThat(refreshed.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(refreshed.getBody().get("accessToken").asText()).isNotBlank();

		ResponseEntity<String> rejected = rest.postForEntity("/api/auth/refresh",
				Map.of("refreshToken", tokens.get("accessToken").asText()), String.class);
		assertThat(rejected.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);

		ResponseEntity<String> badPassword = rest.postForEntity("/api/auth/login",
				Map.of("email", email, "password", "wrong-password"), String.class);
		assertThat(badPassword.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
	}

	@Test
	void dataIsIsolatedPerUser() throws Exception {
		String tokenA = registerAndLogin(email());
		String tokenB = registerAndLogin(email());
		UUID customerId = UUID.randomUUID();
		put(tokenA, "/api/customers/" + customerId, Map.of("name", "Acme", "contactInfo", "555"));

		assertThat(get(tokenB, "/api/customers/" + customerId).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
		assertThat(get(tokenB, "/api/customers").getBody()).isEmpty();

		ResponseEntity<String> stolenWrite = exchange(tokenB, HttpMethod.PUT, "/api/customers/" + customerId,
				Map.of("name", "Stolen"), String.class);
		assertThat(stolenWrite.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
		assertThat(get(tokenA, "/api/customers/" + customerId).getBody().get("name").asText()).isEqualTo("Acme");

		ResponseEntity<String> stolenDelete = exchange(tokenB, HttpMethod.DELETE, "/api/customers/" + customerId, null, String.class);
		assertThat(stolenDelete.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
		assertThat(get(tokenA, "/api/customers").getBody()).hasSize(1);
	}

	@Test
	void relationshipsCascadeAndNotesUseJoins() throws Exception {
		String token = registerAndLogin(email());
		UUID customerId = UUID.randomUUID();
		UUID siteId = UUID.randomUUID();
		UUID noteId = UUID.randomUUID();
		put(token, "/api/customers/" + customerId, Map.of("name", "Acme Water", "contactInfo", "desk@acme.test"));
		put(token, "/api/sites/" + siteId, Map.of("customerId", customerId, "siteName", "North Plant", "address", "1 Dock St"));

		ResponseEntity<String> missingCustomer = exchange(token, HttpMethod.PUT, "/api/sites/" + UUID.randomUUID(),
				Map.of("customerId", UUID.randomUUID(), "siteName", "Orphan"), String.class);
		assertThat(missingCustomer.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);

		Instant notedAt = Instant.parse("2026-10-07T12:00:00Z");
		JsonNode note = put(token, "/api/notes/" + noteId, Map.of(
				"siteId", siteId,
				"title", "Leak",
				"description", "Valve dripping",
				"notedAt", notedAt.toString(),
				"status", "OPEN"));
		assertThat(note.get("site").get("siteName").asText()).isEqualTo("North Plant");
		assertThat(note.get("customer").get("name").asText()).isEqualTo("Acme Water");
		assertThat(note.has("customerName")).isFalse();

		assertThat(get(token, "/api/notes?q=acme").getBody()).hasSize(1);
		assertThat(get(token, "/api/notes?q=NORTH").getBody()).hasSize(1);
		assertThat(get(token, "/api/notes?q=valve").getBody()).hasSize(1);
		assertThat(get(token, "/api/notes?q=leak").getBody()).hasSize(1);
		assertThat(get(token, "/api/notes?q=missing").getBody()).isEmpty();
		assertThat(get(token, "/api/notes?status=COMPLETED").getBody()).isEmpty();
		assertThat(get(token, "/api/notes?status=OPEN&siteId=" + siteId + "&q=plant").getBody()).hasSize(1);

		exchange(token, HttpMethod.DELETE, "/api/customers/" + customerId, null, String.class);
		assertThat(get(token, "/api/sites/" + siteId).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
		assertThat(get(token, "/api/notes/" + noteId).getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
		assertThat(get(token, "/api/notes").getBody()).isEmpty();

		JsonNode pull = get(token, "/api/sync/pull?since=1970-01-01T00:00:00Z").getBody();
		assertThat(pull.get("customers").get(0).get("deletedAt").isNull()).isFalse();
		assertThat(pull.get("sites").get(0).get("deletedAt").isNull()).isFalse();
		assertThat(pull.get("notes").get(0).get("deletedAt").isNull()).isFalse();
		assertThat(pull.get("serverTime").asText()).isNotBlank();
	}

	@Test
	void syncPushIsIdempotentAndIsolatesFailures() throws Exception {
		String token = registerAndLogin(email());
		UUID customerId = UUID.randomUUID();
		UUID otherCustomerId = UUID.randomUUID();
		String createdAt = Instant.parse("2026-10-01T00:00:00Z").toString();

		JsonNode first = push(token, Map.of(
				"customers", List.of(
						Map.of("id", customerId, "name", "First", "contactInfo", "a", "createdAt", createdAt, "deleted", false),
						Map.of("id", otherCustomerId, "name", " ", "deleted", false)),
				"sites", List.of(Map.of(
						"id", UUID.randomUUID(),
						"customerId", UUID.randomUUID(),
						"siteName", "Nowhere",
						"deleted", false)),
				"notes", List.of()));
		assertThat(statusOf(first.get("customers"), customerId)).isEqualTo("APPLIED");
		assertThat(statusOf(first.get("customers"), otherCustomerId)).isEqualTo("ERROR");
		assertThat(first.get("sites").get(0).get("status").asText()).isEqualTo("ERROR");

		JsonNode second = push(token, Map.of(
				"customers", List.of(Map.of(
						"id", customerId, "name", "Renamed", "contactInfo", "b", "createdAt", createdAt, "deleted", false)),
				"sites", List.of(),
				"notes", List.of()));
		assertThat(statusOf(second.get("customers"), customerId)).isEqualTo("APPLIED");

		JsonNode list = get(token, "/api/customers").getBody();
		assertThat(list).hasSize(1);
		assertThat(list.get(0).get("name").asText()).isEqualTo("Renamed");

		UUID siteId = UUID.randomUUID();
		UUID noteId = UUID.randomUUID();
		JsonNode related = push(token, Map.of(
				"customers", List.of(),
				"sites", List.of(Map.of(
						"id", siteId, "customerId", customerId, "siteName", "Yard", "address", "2", "createdAt", createdAt, "deleted", false)),
				"notes", List.of(Map.of(
						"id", noteId,
						"siteId", siteId,
						"title", "Check",
						"description", "ok",
						"notedAt", "2026-10-02T08:00:00Z",
						"status", "IN_PROGRESS",
						"createdAt", createdAt,
						"deleted", false))));
		assertThat(related.get("sites").get(0).get("status").asText()).isEqualTo("APPLIED");
		assertThat(related.get("notes").get(0).get("status").asText()).isEqualTo("APPLIED");
		assertThat(get(token, "/api/notes").getBody()).hasSize(1);

		push(token, Map.of(
				"customers", List.of(),
				"sites", List.of(),
				"notes", List.of(Map.of("id", noteId, "deleted", true))));
		push(token, Map.of(
				"customers", List.of(),
				"sites", List.of(),
				"notes", List.of(Map.of("id", noteId, "deleted", true))));
		assertThat(get(token, "/api/notes").getBody()).isEmpty();
	}

	@Test
	void noteCoordinatesMustBeCompleteAndInRange() throws Exception {
		String token = registerAndLogin(email());
		UUID customerId = UUID.randomUUID();
		UUID siteId = UUID.randomUUID();
		put(token, "/api/customers/" + customerId, Map.of("name", "Geo Co"));
		put(token, "/api/sites/" + siteId, Map.of("customerId", customerId, "siteName", "Dock"));

		UUID noteId = UUID.randomUUID();
		ResponseEntity<String> half = exchange(token, HttpMethod.PUT, "/api/notes/" + noteId,
				Map.of(
						"siteId", siteId,
						"title", "Leak",
						"notedAt", "2026-10-03T09:00:00Z",
						"status", "OPEN",
						"latitude", 23.8),
				String.class);
		assertThat(half.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

		ResponseEntity<String> outOfRange = exchange(token, HttpMethod.PUT, "/api/notes/" + noteId,
				Map.of(
						"siteId", siteId,
						"title", "Leak",
						"notedAt", "2026-10-03T09:00:00Z",
						"status", "OPEN",
						"latitude", 91,
						"longitude", 10),
				String.class);
		assertThat(outOfRange.getStatusCode()).isEqualTo(HttpStatus.BAD_REQUEST);

		JsonNode saved = put(token, "/api/notes/" + noteId, Map.of(
				"siteId", siteId,
				"title", "Leak",
				"notedAt", "2026-10-03T09:00:00Z",
				"status", "OPEN",
				"latitude", 23.8103,
				"longitude", 90.4125));
		assertThat(saved.get("latitude").asDouble()).isEqualTo(23.8103);
		assertThat(saved.get("longitude").asDouble()).isEqualTo(90.4125);
	}

	@Test
	void photoRoundTripAndLaterPull() throws Exception {
		String token = registerAndLogin(email());
		UUID customerId = UUID.randomUUID();
		UUID siteId = UUID.randomUUID();
		UUID noteId = UUID.randomUUID();
		put(token, "/api/customers/" + customerId, Map.of("name", "Photo Co"));
		put(token, "/api/sites/" + siteId, Map.of("customerId", customerId, "siteName", "Roof"));
		put(token, "/api/notes/" + noteId, Map.of(
				"siteId", siteId,
				"title", "Shingle",
				"notedAt", "2026-10-03T09:00:00Z",
				"status", "COMPLETED"));

		byte[] png = Base64.getDecoder().decode(
				"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==");
		HttpHeaders partHeaders = new HttpHeaders();
		partHeaders.setContentType(MediaType.IMAGE_PNG);
		ByteArrayResource resource = new ByteArrayResource(png) {
			@Override
			public String getFilename() {
				return "dot.png";
			}
		};
		LinkedMultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
		body.add("file", new HttpEntity<>(resource, partHeaders));
		HttpHeaders headers = authHeaders(token);
		headers.setContentType(MediaType.MULTIPART_FORM_DATA);
		ResponseEntity<JsonNode> uploaded = rest.exchange("/api/notes/" + noteId + "/photo", HttpMethod.POST,
				new HttpEntity<>(body, headers), JsonNode.class);
		assertThat(uploaded.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(uploaded.getBody().get("photoUrl").asText()).contains("/photo");

		ResponseEntity<byte[]> downloaded = rest.exchange("/api/notes/" + noteId + "/photo", HttpMethod.GET,
				new HttpEntity<>(authHeaders(token)), byte[].class);
		assertThat(downloaded.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(downloaded.getBody()).isEqualTo(png);

		String other = registerAndLogin(email());
		assertThat(get(other, "/api/notes/" + noteId + "/photo").getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
	}

	private JsonNode put(String token, String path, Map<String, ?> body) throws Exception {
		ResponseEntity<JsonNode> response = exchange(token, HttpMethod.PUT, path, body, JsonNode.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		return response.getBody();
	}

	private ResponseEntity<JsonNode> get(String token, String path) {
		return exchange(token, HttpMethod.GET, path, null, JsonNode.class);
	}

	private JsonNode push(String token, Map<String, ?> body) {
		ResponseEntity<JsonNode> response = exchange(token, HttpMethod.POST, "/api/sync/push", body, JsonNode.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		return response.getBody();
	}

	private <T> ResponseEntity<T> exchange(String token, HttpMethod method, String path, Object body, Class<T> type) {
		return rest.exchange(path, method, new HttpEntity<>(body, authHeaders(token)), type);
	}

	private HttpHeaders authHeaders(String token) {
		HttpHeaders headers = new HttpHeaders();
		headers.setBearerAuth(token);
		headers.setContentType(MediaType.APPLICATION_JSON);
		return headers;
	}

	private String registerAndLogin(String email) throws Exception {
		ResponseEntity<String> created = rest.postForEntity("/api/auth/register",
				Map.of("email", email, "password", "password123"), String.class);
		assertThat(created.getStatusCode()).isEqualTo(HttpStatus.CREATED);
		return login(email).get("accessToken").asText();
	}

	private JsonNode login(String email) throws Exception {
		ResponseEntity<String> response = rest.postForEntity("/api/auth/login",
				Map.of("email", email, "password", "password123"), String.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		return objectMapper.readTree(response.getBody());
	}

	private static String email() {
		return "user-" + UUID.randomUUID() + "@field.test";
	}

	private static String statusOf(JsonNode items, UUID id) {
		for (JsonNode item : items) {
			if (id.toString().equals(item.get("id").asText())) {
				return item.get("status").asText();
			}
		}
		throw new AssertionError("Missing sync result " + id);
	}
}
