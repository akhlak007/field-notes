# 🛠️ Field Notes — Build Prompt (Offline-First Mobile App + REST Backend)

> Paste this whole file into your AI coding assistant inside the project repo to build this exact feature set. Reference `FIELD_NOTES_PROJECT_STARTER.md` in the same repo for full context (PRD, architecture, rules, phases, memory). Two sub-projects are expected: `mobile/` (Flutter) and `backend/` (Spring Boot).

---

## Context
You are working on **Field Notes**, a mobile app + REST backend for field workers to record notes during site visits. Build the following flows exactly as specified. Do not add extra features or extra steps. A partial but correct and working solution is better than a broad but broken one — build in the priority order in Section 11.

**Required stack (non-negotiable):**
- Mobile: Flutter, **BLoC** for state management, **Hive or SQLite** (pick SQLite via `drift`/`sqflite` if you need JOIN-style search; otherwise Hive), REST via `dio`.
- Backend: **Java + Spring Boot**, **PostgreSQL or MySQL**, Spring Security + JWT, Spring Data JPA (or JdbcTemplate for the search query), Flyway for migrations.

---

## 1. Data Model — relational, no duplicated data

```
users      (id PK, email UNIQUE, password_hash, created_at)
customers  (id PK UUID, user_id FK→users, name, contact_info, created_at, updated_at, deleted_at NULL)
sites      (id PK UUID, user_id FK→users, customer_id FK→customers, site_name, address, created_at, updated_at, deleted_at NULL)
field_notes(id PK UUID, user_id FK→users, site_id FK→sites, title, description,
            latitude, longitude, noted_at, status, photo_url NULL,
            created_at, updated_at, deleted_at NULL)
```

**Rules:**
- A customer has many sites; a site has many field notes. Store only foreign keys — **never** copy customer name or site name into a note or site row.
- Primary keys are **UUIDs generated on the client** so records can be created offline without ID collisions.
- Every table carries `user_id`, `updated_at` (server-assigned on write), and `deleted_at` (soft delete, needed so deletions can sync).
- `status` is an enum: `OPEN`, `IN_PROGRESS`, `COMPLETED` (keep it a fixed set; the Settings default uses the same values).
- Add indexes on `(user_id, updated_at)` for every table, and on `site_id` / `customer_id` FKs.
- Local DB mirrors this schema, plus a `sync_state` column per row (`synced`, `pending_upsert`, `pending_delete`).

---

## 2. Authentication & Data Isolation (Backend)

- `POST /api/auth/register` → `{email, password}` → creates user.
- `POST /api/auth/login` → returns `{accessToken, refreshToken, expiresIn}`.
- `POST /api/auth/refresh` → new access token.
- Passwords hashed with BCrypt. JWT access token sent as `Authorization: Bearer <token>`.
- **Every** query filters by the authenticated user's id, taken from the JWT, **never from a request parameter or body**. A user must never be able to read or modify another user's rows, including by guessing a UUID (return 404, not 403, for foreign IDs).
- Validate that a site's `customerId` and a note's `siteId` belong to the same user before saving.

---

## 3. REST API

All routes under `/api`, JSON, authenticated except `/auth/*`.

| Resource | Endpoints |
|---|---|
| Customers | `GET /customers`, `GET /customers/{id}`, `PUT /customers/{id}` (upsert by client UUID), `DELETE /customers/{id}` |
| Sites | same shape, `GET /sites?customerId=` |
| Notes | same shape, `GET /notes?status=&siteId=&q=` |
| Photo | `POST /notes/{id}/photo` (multipart), `GET /notes/{id}/photo` |
| Sync | `POST /sync/push`, `GET /sync/pull?since=<ISO timestamp>` |

**Relational reads (must use JOINs, not duplicated data):**
- `GET /notes` returns each note with `site` and `customer` info resolved via `field_notes JOIN sites JOIN customers`, in a single query (no N+1).
- `q` search runs server-side as a JOIN across `title`, `description`, `site_name`, and `customer.name` using case-insensitive `LIKE`/`ILIKE`, scoped to the user and excluding soft-deleted rows.
- Deleting a customer soft-deletes its sites and notes in one transaction. Deleting a site soft-deletes its notes.

---

## 4. Offline-First Sync Design — implement exactly this

**Principle:** the local database is the source of truth for the UI. The UI never waits on the network.

**Writes (client):**
1. Every create/edit/delete is written to the local DB immediately and marked `pending_upsert` or `pending_delete`.
2. Deletes are soft: the row stays locally (hidden from the UI) until the server confirms.
3. The UI reads only from the local DB.

**Push (client → server):**
- A `SyncService` collects all pending rows and sends them to `POST /sync/push` as a batch, in dependency order: customers → sites → notes (so FKs exist when notes arrive).
- The server applies each change as an **idempotent upsert by UUID** inside a transaction, sets `updated_at` itself, and returns the stored rows. Re-sending the same batch must be safe.
- On success, the client marks rows `synced` and stores the server's `updated_at`.
- On failure, rows stay pending and are retried with exponential backoff. One bad row must not block the rest (return per-item results).

**Pull (server → client):**
- `GET /sync/pull?since=<lastSyncAt>` returns all of the user's customers, sites, notes (including soft-deleted ones, flagged via `deletedAt`) changed after `since`.
- The client applies them to the local DB. Soft-deleted rows are removed locally.
- Store `lastSyncAt` using the **server's** timestamp, not the device clock.

**Conflict policy:** last-write-wins by server `updated_at`. Do not overwrite a local row that is still `pending_*` with a pulled version, push first, then pull.

**Triggers:** app start, successful login, connectivity regained (`connectivity_plus`), after every local write when online, and a manual pull-to-refresh. Show a small sync indicator (synced / syncing / pending count / offline).

**Photos:** store the file locally and sync it separately after the note's metadata is pushed, via the multipart endpoint. A note with a pending photo upload must remain usable.

**Restore after reinstall / cleared data:** logging in on an empty local DB triggers `pull?since=` (epoch) to restore everything, including photos (download lazily).

---

## 5. Features (Mobile)

- **Auth screens:** register, login. Store tokens in `flutter_secure_storage`. Registration and first login require internet; after that the app works fully offline. Handle expired tokens by refreshing, and if refresh fails while offline, keep the user working locally and defer sync.
- **Customers / Sites / Notes:** list, view, create, edit, delete for each, with relationship navigation (customer → its sites → a site's notes). Deleting a parent asks for confirmation and states what will also be deleted.
- **Note form:** site picker, title, description, location, date & time, status, optional photo.
- **Search:** one search field on the notes list matching title, description, site name, or customer name. Offline, run this as a local JOIN query (SQLite) so results match the server behavior.
- **Filters:** by status and by site, combinable with search.
- **Permissions:** request location when the user taps "Use current location" and camera/gallery only when attaching a photo (`permission_handler` or the pickers' own flow). Handle denied and permanently-denied states with a clear message and a button to open app settings. A note can still be saved with manual/no location if permission is denied.
- **UI:** clean, simple Material 3, empty states, loading states, form validation, no dead ends.

---

## 6. Settings — Default Note Status

- A Settings screen with a "Default Note Status" selector (`OPEN` / `IN_PROGRESS` / `COMPLETED`).
- Persist locally only (Hive box or `shared_preferences`). **Do not sync it** and do not add a backend endpoint for it.
- The new-note form pre-selects this value. It must survive app restarts. Changing it must not alter existing notes.

---

## 7. BLoC Architecture

- Layers: `data` (remote API client, local DAO, repositories) → `domain`/repository interfaces → `presentation` (BLoCs + screens).
- Separate BLoCs: `AuthBloc`, `CustomerBloc`, `SiteBloc`, `NoteBloc` (with search/filter state), `SyncBloc` (status stream), `SettingsBloc`.
- Repositories expose streams from the local DB so the UI updates automatically after writes and after pulls.
- No business logic in widgets. No direct DB or HTTP calls from BLoCs, go through repositories.

---

## 8. Backend Structure

- Packages: `controller`, `service`, `repository`, `entity`, `dto`, `security`, `config`.
- DTOs for all requests/responses (never expose entities). Bean validation on inputs. A global `@ControllerAdvice` returning consistent error JSON.
- Flyway migrations for the schema. Config via `application.yml` with env-var overrides (DB URL, JWT secret).
- A `README.md` with run instructions (DB setup, `./mvnw spring-boot:run`, base URL, how to point the app at it).

---

## 9. What NOT to do
- Do not duplicate customer or site fields inside notes or sites.
- Do not trust a `userId` sent by the client; always use the one from the JWT.
- Do not let the UI block on network calls or show errors for offline operation.
- Do not hard-delete rows server-side during sync (deletions would never propagate).
- Do not use device time as the sync cursor.
- Do not sync the Default Note Status setting.
- Do not add features beyond this spec (no roles, no teams, no maps screen, no push notifications).

---

## 10. Acceptance Checklist (verify before marking done)
- [ ] Register and log in against the backend; data is isolated per user (verified with two accounts).
- [ ] Full CRUD works for customers, sites, and notes, with relationships enforced (a site requires a customer, a note requires a site).
- [ ] Notes list API returns customer and site info through JOINs, with no duplicated stored data.
- [ ] Airplane mode: create, edit, and delete all three entity types without errors.
- [ ] Turning the network back on automatically pushes pending changes, and the server reflects them.
- [ ] Changes made on the server/another device appear after pull.
- [ ] Deletions made offline propagate to the server; deletions on the server propagate to the device.
- [ ] Re-sending the same push batch creates no duplicates.
- [ ] Uninstall/clear data → log in → all data (and photos) is restored.
- [ ] Search matches title, description, site, and customer, online and offline.
- [ ] Filters by status and site work and combine with search.
- [ ] Denied location/camera/gallery permission is handled gracefully.
- [ ] Default Note Status is applied to new notes and persists across restarts, and is not sent to the backend.

---

## 11. Build Order (if time runs short, stop at the last completed step)
1. Backend: schema, auth, isolation, CRUD for the three entities.
2. Mobile: auth + online CRUD with local DB as the UI source.
3. Offline writes + sync push/pull + restore on login.
4. Search, filters, JOIN-based notes query.
5. Photo + location + permissions.
6. Settings (Default Note Status).
7. Polish, README, and tests for the sync service and the isolation rules.
