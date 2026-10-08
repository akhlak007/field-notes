# 🚀 Field Notes — Project Starter

> Offline-first mobile app + REST backend for field workers (Flutter + Spring Boot)
> Generated from the Field Notes take-home task. Use this as the foundation doc set. Pair it with `FIELD_NOTES_BUILD_PROMPT.md`.

---

## 📄 1. PRD.md — Product Requirement Document

### 1. What to Build
- **Product name:** Field Notes
- **One-line pitch:** A field-worker app for recording notes during site visits that works fully offline and syncs automatically when the connection returns.
- **Core purpose:** Let workers capture customer, site, and note data anywhere (including dead zones) without losing work, and recover everything from the server after a reinstall.
- **Goals:**
  - Business: reliable data capture tied to the right customer and site, with clean relational records.
  - User: never be blocked by connectivity; find any past note quickly.

### 2. Targeted User
- **Primary audience:** Field workers doing site visits (inspections, installations, maintenance).
- **Needs / pain points:**
  - Poor or no signal on site.
  - Notes scattered across paper, photos, and chat apps.
  - Hard to find which customer/site a note belongs to.
- **Use cases:**
  - "Log a leak I found at Site B, attach a photo, and tag my location."
  - "Find every open note for this customer."
  - "I got a new phone, restore all my data."

### 3. Core Flow
1. Register and log in (online).
2. Create customers → add sites under each customer → create notes for sites.
3. Keep working offline (create, edit, delete).
4. Changes sync automatically when connectivity returns.
5. After reinstall or cleared data, log in and restore everything from the server.

### 4. Features (scope)
- [ ] Register / login with JWT (must-have)
- [ ] CRUD for customers, sites, field notes (must-have)
- [ ] Relational model: customer → sites → notes, no duplicated data (must-have)
- [ ] Offline-first local storage + automatic sync (must-have, core)
- [ ] Restore from server after reinstall (must-have)
- [ ] Search notes by title, description, site, customer (must-have)
- [ ] Filter notes by status or site (must-have)
- [ ] Location + camera/gallery with proper permission handling (must-have)
- [ ] Settings: Default Note Status, local-only, persisted (must-have)
- [ ] Clean, easy-to-use UI (must-have)
- [ ] Optional note photo sync (should-have)
- [ ] Out of scope: roles/teams, maps screen, push notifications, web client

---

## 🏗️ 2. architecture.md — High-Level Design & Structure

### 1. Architecture
- **Client:** Flutter app, BLoC state management, local DB (SQLite via drift/sqflite recommended for JOIN search; Hive acceptable).
- **Backend:** Spring Boot REST API, Spring Security + JWT, Spring Data JPA, PostgreSQL (or MySQL), Flyway migrations.
- **Data flow:**
  UI → BLoC → Repository → Local DB (always) → SyncService → REST API → Database
  The UI reads only from the local DB; the network never blocks the UI.

### 1.1. Core Sync Logic (confirmed)
- **Client-generated UUIDs** for all entities so offline creation never collides.
- **Outbox pattern:** every local write marks the row `pending_upsert` or `pending_delete`.
- **Push:** batch in dependency order (customers → sites → notes) to `POST /api/sync/push`. Server applies idempotent upserts by UUID and sets `updated_at`.
- **Pull:** `GET /api/sync/pull?since=<server timestamp>` returns changed rows including soft-deleted ones.
- **Conflict policy:** last-write-wins by server `updated_at`; push pending changes before pulling.
- **Soft deletes** (`deleted_at`) so deletions propagate across devices.
- **Cursor:** server timestamp, never device time.
- **Restore:** login on empty local DB → pull from epoch.
- **Triggers:** app start, login, connectivity regained, after local write when online, manual refresh.
- **Photos:** uploaded separately (multipart) after the note metadata syncs.

### 2. Folder & File Structure

~~~
field_notes/
├── mobile/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── core/
│   │   │   ├── constants/
│   │   │   ├── routing/
│   │   │   ├── theme/
│   │   │   └── network/            # dio client, auth interceptor, connectivity
│   │   ├── data/
│   │   │   ├── local/              # DB, DAOs, sync_state handling
│   │   │   ├── remote/             # REST API client, DTOs
│   │   │   └── repositories/
│   │   ├── sync/
│   │   │   └── sync_service.dart   # push/pull, backoff, triggers
│   │   ├── features/
│   │   │   ├── auth/               # bloc + screens
│   │   │   ├── customers/
│   │   │   ├── sites/
│   │   │   ├── notes/              # list, search, filters, form
│   │   │   └── settings/           # Default Note Status
│   │   └── shared/
│   │       ├── widgets/
│   │       └── models/
│   ├── test/
│   └── pubspec.yaml
├── backend/
│   ├── src/main/java/com/fieldnotes/
│   │   ├── controller/
│   │   ├── service/
│   │   ├── repository/
│   │   ├── entity/
│   │   ├── dto/
│   │   ├── security/
│   │   └── config/
│   ├── src/main/resources/
│   │   ├── application.yml
│   │   └── db/migration/           # Flyway SQL
│   ├── src/test/
│   └── pom.xml
└── docs/                           # PRD, architecture, design, rules, phases, memory
~~~

### 3. Database Model (high-level)

~~~
users       (id, email UNIQUE, password_hash, created_at)
customers   (id UUID, user_id FK, name, contact_info, created_at, updated_at, deleted_at)
sites       (id UUID, user_id FK, customer_id FK, site_name, address, created_at, updated_at, deleted_at)
field_notes (id UUID, user_id FK, site_id FK, title, description,
             latitude, longitude, noted_at, status, photo_url,
             created_at, updated_at, deleted_at)
~~~

- Status enum: `OPEN`, `IN_PROGRESS`, `COMPLETED`.
- Indexes on `(user_id, updated_at)` per table and on FK columns.
- Notes list and search use `field_notes JOIN sites JOIN customers`, with no duplicated names stored.

### 4. API Surface
- `POST /api/auth/register`, `/login`, `/refresh`
- `GET|PUT|DELETE /api/customers`, `/api/sites`, `/api/notes` (PUT = upsert by client UUID)
- `GET /api/notes?status=&siteId=&q=`
- `POST|GET /api/notes/{id}/photo`
- `POST /api/sync/push`, `GET /api/sync/pull?since=`

### 5. Tech Stack
- **Mobile:** Flutter, `flutter_bloc`, `dio`, `drift`/`sqflite` or `hive`, `connectivity_plus`, `flutter_secure_storage`, `geolocator`, `image_picker`, `permission_handler`, `shared_preferences` (settings).
- **Backend:** Java 17+, Spring Boot 3, Spring Security, JPA/Hibernate, Flyway, PostgreSQL/MySQL, JUnit + Testcontainers.

---

## 🎨 3. design.md — UI/UX Guidelines

### 1. UI/UX Principles
- Clean, simple Material 3; one primary action per screen.
- Offline is a normal state, not an error. Show a small sync indicator (synced / syncing / N pending / offline).
- Thumb-friendly forms with sensible defaults (Default Note Status, current time prefilled).
- Always provide empty, loading, and validation states.

### 1.1. Screen Flow
1. **Login / Register**
2. **Home (Notes list)** — search bar, status and site filter chips, sync indicator, FAB to add note
3. **Note detail / form** — site picker, title, description, location button, date & time, status, photo (camera/gallery)
4. **Customers list** → **Customer detail** (its sites) → **Site detail** (its notes)
5. **Create/Edit Customer, Create/Edit Site**
6. **Settings** — Default Note Status selector
7. Bottom navigation: Notes · Customers · Settings

### 2. Color & Theme
- Primary / secondary / accent: TBD (suggest a work-oriented blue/teal).
- Status colors: Open (amber), In Progress (blue), Completed (green).
- Light and dark theme: yes.

### 3. Typography
- Clear hierarchy: note titles as headings, descriptions as body, site/customer as secondary labels.
- Font family: TBD (system default or Inter).

### 4. Memory (UI Preferences)
- Default Note Status (local only, persists across restarts, never synced).
- Last used filters (optional).
- Theme mode (optional).

---

## 📜 4. rules.md — Project Rules, Standards & Guidelines

### 1. What to Use
- Flutter + BLoC (one pattern, consistently).
- Spring Boot + PostgreSQL/MySQL with proper relational design.
- Local DB as the UI's source of truth.
- UUIDs generated on the client; JWT auth; Flyway for schema.

### 2. What to Avoid
- No duplicated customer/site data inside notes or sites.
- No trusting a client-supplied `userId`; always derive it from the JWT.
- No blocking the UI on network calls.
- No hard deletes during sync.
- No device time as the sync cursor.
- No syncing the Default Note Status setting.
- No extra features beyond the spec.

### 3. Libraries & Dependencies
- Mobile and backend lists in architecture.md §5; pin versions in `pubspec.yaml` and `pom.xml`.

### 4. Error Handling
- Offline = normal; queue and retry with exponential backoff.
- One failing item must not block the rest of a sync batch (per-item results).
- Clear messages for auth failures, validation errors, and denied permissions.
- Consistent backend error JSON via `@ControllerAdvice`.

### 5. Data Isolation (hard rule)
- Every query is scoped to the authenticated user.
- Foreign IDs return 404.
- Validate that `customerId` and `siteId` references belong to the same user before saving.

### 6. Permissions
- Request location only when the user taps "Use current location"; request camera/gallery only when attaching a photo.
- Handle denied and permanently denied states with a message and an "Open settings" action. Notes remain savable without location or photo.

### 7. General Rules
- Layered code: BLoC → Repository → (Local | Remote). No DB or HTTP calls from widgets or BLoCs.
- DTOs only at the API boundary; never expose entities.
- Clear commit messages (e.g., `feat(sync): add idempotent push endpoint`).
- Tests: sync service (push/pull/retry/conflict), data isolation, search query, settings persistence.
- README with run instructions for both projects.

### 8. Boundaries of AI (if using AI coding assistants)
- The task asks candidates to avoid heavy reliance on agentic coding tools. Use AI for boilerplate and review only; write and understand the sync, auth, and isolation logic yourself.
- You must be able to explain every design decision.

---

## 🗺️ 5. phases.doc.md — Breakdown into Manageable Phases

### Phase 1: Backend foundation
- Schema + Flyway, register/login/refresh, JWT, CRUD for customers/sites/notes with isolation.

### Phase 2: Mobile online core
- Auth screens, local DB, repositories, online CRUD with UI reading from local DB.

### Phase 3: Offline + Sync
- Outbox, push/pull endpoints, SyncService, connectivity triggers, restore on login.

### Phase 4: Search & Filters
- JOIN-based notes query (server and local), status/site filters.

### Phase 5: Photo, Location, Permissions
- Camera/gallery, geolocation, permission edge cases, photo sync.

### Phase 6: Settings
- Default Note Status, local persistence, applied to new notes.

### Phase 7: Polish & Testing
- UI cleanup, empty/loading states, tests, README. Submit a partial solution if time runs out, ordered by phase.

---

## 🧠 6. memory.md — Project Memory (Progress & Decisions)

### 1. Memory
- **Project:** Field Notes — offline-first field-worker notes app (Flutter + Spring Boot).
- **Confirmed stack:** Flutter + BLoC + Hive/SQLite + REST; Spring Boot + PostgreSQL/MySQL.
- **Sync design:** client UUIDs, outbox, idempotent push, delta pull by server timestamp, soft deletes, last-write-wins.
- **Key constraints:** data isolation per user; no duplicated customer/site data; Default Note Status is local only.
- **Submission note:** partial solutions are acceptable; avoid heavy reliance on agentic tools.

### 2. What Happened
- [Date] — Take-home task received.
- [Date] — Build prompt and project starter created.
- (Log major decisions here, e.g., SQLite vs Hive, conflict policy changes.)

### 3. Currently Working
- Task/module in progress: Phase 1 — Backend foundation
- Next: schema + auth endpoints

### 4. Updates
- Update this file after every work session.
- Open items: colors/fonts, Hive vs SQLite final choice, photo storage location (local disk vs object store).

### 5. Purpose
- Keep context consistent across sessions and tools.
- Avoid re-debating settled decisions (sync model, isolation rules).

---

## ✅ Next Steps
1. Split this into `docs/` files or keep as one master file in the repo root.
2. Run `flutter create mobile` and scaffold `backend/` with Spring Initializr (Web, Security, JPA, Validation, Flyway, PostgreSQL driver).
3. Set up a local PostgreSQL/MySQL database and the Flyway baseline migration.
4. Build in the order of `phases.doc.md`, logging progress in `memory.md`.
5. Treat `rules.md` §5 (isolation) and §8 (AI boundaries) as hard guardrails.
