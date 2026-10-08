# Recruiter audit — Field Notes

Reviewed as a 15-minute hiring-engineer pass on 8 October 2026. Status reflects the repo **before** the polish work in this session. Line numbers are from that snapshot.

## Summary

The product is further along than a typical take-home: Flutter + BLoC + Drift SQLite, Spring Boot + Flyway + PostgreSQL, JOIN search, per-user sync cursor, and offline CRUD already exist. A recruiter would still bounce on **submission packaging**: no public backend, no Dockerfile, `docker compose` starts only Postgres, the release APK would talk to `10.0.2.2`/`localhost`, cleartext is allowed globally, README has no live URL / APK / screenshots / demo video, and the UI is close but not token-accurate. Functional core is mostly Done; APK-on-a-real-phone is the main risk.

## Requirement table

| Requirement | Status | Evidence | Fix needed |
|---|---|---|---|
| README clarity (overview, setup, demo) | Partial | `README.md` covers local `run.ps1` / Docker DB / Flutter `--dart-define`. No live API URL, APK link, screenshots, demo video, test credentials, or architecture diagram. | Rewrite README for submission; add `docs/screenshots/`. |
| Top-level structure | Partial | Root has `backend/`, `mobile/`, `docs/`, `docker-compose.yml`, `.env.example`. Missing `backend/Dockerfile`, `docs/ARCHITECTURE.md`, `docs/API.md`, `docs/SYNC.md`. | Add missing docs and Docker files. Do not rewrite feature folders. |
| `.gitignore` (Flutter, Maven, IDE, secrets, keystores) | Partial | Root `.gitignore` ignores `.env`, `backend/target/`, `mobile/build/`. Missing `*.jks`, `key.properties`, `*.keystore`. | Extend gitignore. Confirm no secrets in git. |
| No committed secrets / build folders / `.env` / keystores | Partial | `.env.example` only; `.env` ignored. Need git history check. `backend/target/` and `mobile/build/` exist locally (ignored). | Verify `git ls-files`; never commit keystores. |
| Auth (register / login / JWT / refresh) | Done | `AuthController.java` 27–40; `AuthService`; mobile `auth_bloc.dart` 117–196; tests `FieldNotesApiTest.java` 53–81. | Keep. |
| Customers / sites / notes CRUD | Done | Controllers under `backend/src/main/java/com/fieldnotes/controller/`; mobile repositories + BLoCs in `features/`. | Keep. |
| Relationships (customer → sites → notes, FKs only) | Done | `V1__init.sql` 8–52; note reads JOIN site+customer (`NoteQueryRepository.java` 29–41). Local Drift JOINs in `app_database.dart` / `note_repository.dart` 135–156. | Keep. Note UI omits site **address** on detail even though JOIN has it. |
| User isolation (foreign IDs → 404) | Done | `CustomerService.java` 46–48, 80–82; same pattern on sites/notes; test `dataIsIsolatedPerUser` `FieldNotesApiTest.java` 83–101. | Keep. |
| Offline CRUD (local SQLite is UI source of truth) | Done | Repositories write Drift then notify `LocalChangeBus`; widgets read BLoC/DB. No `Dio` in widgets (only `main.dart` + `data/remote`). | Keep. |
| Auto-sync (launch, local change, connectivity, manual) | Done | `SyncBloc` start/connectivity/change bus; notes pull-to-refresh `note_pages.dart` 161–163. | Keep. |
| Restore after reinstall (pull from `since=epoch`) | Done | `SyncService._pull` uses `lastSyncAt` or 1970 (`sync_service.dart` 122–136). Empty DB + login triggers `SyncStarted`. | Keep. Physical-device verification not recorded. |
| Search title / description / site / customer | Done | Server JOIN LIKE `NoteQueryRepository.java` 52–61; local `watchNotes` + test `sync_and_search_test.dart` 27–84. | Keep. Search hint already matches design. |
| Filter by status / site | Done | `NoteBloc` filters; UI chips + site dropdown `note_pages.dart` 101–128. | Keep. |
| Location + camera/gallery permissions (denied ≠ crash) | Partial | Requests in `note_bloc.dart` 322–363; snackbar + Open settings `common.dart` 661–674. Android: INTERNET, location, CAMERA, READ_MEDIA_IMAGES (`AndroidManifest.xml` 2–7). Missing `ACCESS_NETWORK_STATE`. iOS usage strings exist (`Info.plist` 52–57). | Add network-state permission; keep denied path. |
| Default note status local-only, applied to new notes | Done | `SettingsRepository` SharedPreferences key `default_note_status`; form reads it `note_pages.dart` 478; never in sync payload `sync_service.dart` 218–251. Test `settings_repository_test.dart`. | Optional: key per user so two accounts on one phone do not share the default. |
| Relational schema + FKs + indexes | Done | `V1__init.sql` FKs and `(user_id, updated_at)` indexes. JPA `ddl-auto: validate` (`application.yml` 13–14). | Keep. |
| JOIN-based reads, no duplicated customer/site names | Done | `NoteQueryRepository.java` 29–107; DTO nested `site`/`customer`; test asserts `has("customerName")` is false (`FieldNotesApiTest.java` 123–125). | Keep. |
| Validation + consistent error JSON | Done | Bean validation + `GlobalExceptionHandler.java`; `ApiError` record; lat/lng `NoteService.java` 127–136. | Add an API test for half-filled / out-of-range coordinates. |
| Flyway on start | Done | `application.yml` 17–18; `V1__init.sql`. | Keep. |
| Backend tests (auth, isolation, JOIN, cascade, sync idempotency) | Done | `FieldNotesApiTest.java` 53–249 (Testcontainers). Photo isolation included. | Add coordinate validation cases. |
| BLoC consistently; no network in widgets | Done | Feature BLoCs; Dio only in `main.dart` + `FieldNotesApi`. | Keep. |
| Local DB is UI source of truth | Done | Notes/customers/sites watch Drift streams. | Keep. |
| Sync cursor per user `last_sync_at:<userId>` | Done | `app_database.dart` 407–421; tests in `sync_and_search_test.dart`. | Ignore any leftover global `last_sync_at` key if present (none written today). |
| Sign-out / user change: cancel retries, no cross-user rows | Done | `SyncStopped` cancels timer (`sync_bloc.dart` 126–131); `app.dart` 38–42 stops watches; pending queries filter `userId`; logout only clears tokens (`auth_repository.dart` 51). Warn if pending `settings_page.dart` 79–90. | Keep. |
| 401 refresh failure signs out, keeps local pending | Done | `AuthInterceptor` 53–69, 94–99; `SessionExpired` → logout tokens only. | Keep. |
| Sync failure surfaced + Retry, queue kept | Partial | Error on `SyncState`; list chip becomes the word “Retry” (`common.dart` 122) instead of “Failed” + Retry. Banner has Retry. | Match design: Failed + Retry on the pill. |
| No leftover debug prints | Done | No `print`/`debugPrint` in `mobile/lib`. | Keep `flutter analyze` clean. |
| `flutter analyze` clean | Partial | Not re-run in this audit pass. Gradle file still has Flutter TODOs (`android/app/build.gradle.kts` 18, 34). | Run analyze; remove TODO noise. |
| API base URL not hard-coded for a real phone | Partial | `apiBaseUrl()` in `constants.dart` 39–44: `--dart-define=API_BASE_URL`, else Android `10.0.2.2:8080`, else `localhost:8080`. Release APK without dart-define **cannot reach a public API**. Not a dedicated `AppConfig` class. | `AppConfig`; document release dart-define; default must not be localhost for store/demo APK. |
| Public HTTPS backend | Missing | No Render/Railway/Fly config. README points at `localhost:8080`. No `/api/health` or actuator (`SecurityConfig.java` 30–33 denies unknown paths). | Add health endpoint; Dockerize; deploy or document LAN `http://<lan-ip>:8080`. |
| Android permissions complete | Partial | Main manifest has INTERNET (good for release). Missing `ACCESS_NETWORK_STATE`. `usesCleartextTraffic="true"` globally (`AndroidManifest.xml` 12) — too wide for a demo APK. | Host-scoped network security config; add `ACCESS_NETWORK_STATE`. |
| Release build includes INTERNET / not stripped | Partial | INTERNET is in **main** manifest (correct). Release still **signs with debug keys** (`build.gradle.kts` 32–37). Minify/R8 not enabled (low strip risk). | Local keystore via `key.properties` (gitignored); document `flutter build apk --release --dart-define=...`. |
| Backend bind `0.0.0.0` + `PORT` + JWT from env | Partial | `PORT` and `JWT_SECRET` in `application.yml`. Spring default bind is all interfaces (OK). No explicit `server.address`. | Set `server.address: 0.0.0.0` for PaaS; keep env vars. |
| Dockerize (`Dockerfile` + compose DB+API) | Missing | `docker-compose.yml` is **Postgres only**. No `backend/Dockerfile`. | Multi-stage Maven image; compose `db` + `backend`. |
| Release APK artifact / GitHub Release | Missing | Release signing is debug; no documented APK name. | Build `FieldNotes-v1.0.apk`; attach to GitHub Release (needs remote + user). |
| Physical-device scenarios recorded | Missing | README describes airplane-mode intent but does not record results. | Run or mark “not run on a physical phone in this session”. |
| UI vs approved design — tokens | Partial | `AppTheme` uses `#0C6B64` / `#EEF4F2` / `#122926` (`app_theme.dart` 4–20) vs design `#0F766E` / `#F2F7F6` / `#10272A`. Status colors off (Open `#F7EDD6` vs `#FEF3C7`). Card radius 20 vs 16; buttons 18 vs 14. | Align `AppColors` and radii. |
| UI — font Plus Jakarta Sans (bundled) | Missing | No `fonts:` in `pubspec.yaml`; system Material font. | Bundle Regular/Medium/Bold/ExtraBold as assets. |
| UI — sign-in | Partial | Teal welcome, FN mark, mode toggle keeps email, password visibility, inline errors (`auth_page.dart`). Uses drawn “FN” text, not `field_notes_logo.svg` / `flutter_svg`. `pubspec` lists `assets/logo.png` but **no png/svg files found in the repo**. | Add SVG logo; `flutter_svg`; launcher icons from 1024px PNG. |
| UI — notes list | Partial | Header counts, search, status chips, cards, FAB, bottom nav. Sync chip exists but not “Synced / Syncing / N pending / Offline / Failed + Retry” as specified. Site filter is a dropdown (acceptable). | `SyncPill` labels; keep FAB. |
| UI — note form | Partial | Site, title, description, status+datetime row, location, photo, default status. No location **clear**. Status is a dropdown, not the design’s field/chip. | Add clear; use status pills; keep validation. |
| UI — note detail | Partial | Back, badge, title, rounded photo, site/customer card, details, edit/delete confirm. Site card omits address (`note_pages.dart` 373–390). `FieldNote` has no `siteAddress`. | Pass JOIN address through the model. |
| UI — customers / sites | Done | List → detail → nested forms; empty states; delete confirm. | Visual token pass only. |
| UI — settings | Done | Account, default status + helper, sync copy, sign-out warn. | Token pass; sign-out already warns on pending. |
| Empty / loading / offline / error / delete confirm | Partial | Empty + loading + delete dialogs exist. Offline is a chip, not a full-page state. Sync error is a banner/chip. | Keep; polish SyncPill. |
| Light + dark `ThemeData` | Done | `AppTheme.light()` / `dark()` wired in `app.dart` 24–25. Dark status chips still use light tints. | Tune dark contrast. |
| Shared widgets (`SectionCard`, `StatusBadge`, `EmptyState`, `SyncPill`, `PrimaryButton`, `AppTextField`, `ResponsiveBody`) | Partial | `SectionCard`, `StatusBadge`, `EmptyState` exist. `SyncChip` / `ContentWidth` / `BottomBarButton` are the same idea under other names. | Add aliases or rename to the spec names. |
| App name “Field Notes” | Done | Android label `AndroidManifest.xml` 9; iOS display name `Info.plist` 9–10. | Launcher icon still default Flutter look without generated icons. |
| Demo video 2–4 min | Missing | Not in repo. | Candidate must record; link in README. |
| GitHub hygiene (`v1.0` tag, Release) | Missing | Not verified in this pass. | After polish: meaningful commits, tag, Release with APK. **Do not commit secrets.** |

## Phase C — what would fail on a real phone today

1. **Wrong host.** A release APK without `--dart-define=API_BASE_URL=...` uses `http://10.0.2.2:8080` on Android. That is the emulator’s host loopback, not a phone on Wi‑Fi and not the public internet.
2. **No public API.** Reviewers cannot reach the candidate’s laptop. There is no health URL to poke while a free tier wakes up.
3. **HTTP cleartext is global.** `android:usesCleartextTraffic="true"` works for LAN HTTP but is sloppy; a phone on HTTPS would be fine if the URL were set.
4. **Release signing is the debug keystore.** Installable for a demo, not a real release identity. Play Protect may warn.
5. **`docker compose up` does not start the API.** Only Postgres runs.
6. **Permissions.** Camera/location/photos are declared; denied paths snackbar rather than crash (good). Missing `ACCESS_NETWORK_STATE` is minor. Gallery on Android 13+ uses `READ_MEDIA_IMAGES` (good).
7. **Logo asset missing.** `pubspec.yaml` references `assets/logo.png` but the file is not in the tree — `Image.asset` on splash/`AppLogo` can fail if that widget is shown.

## UI gaps vs the approved screenshots

- Sign-in: layout is already close (teal, card, Sign in/Register). Logo should be the FN tile SVG, not a `Text('FN')`. Primary should be `#0F766E`.
- Notes: “Synced” pill should be the light-green capsule in the header (exists, colors off). Cards, badges, and bottom nav are the right structure.
- New note: needs location clear; “Camera or gallery” field matches; status should read as a simple control, not a dense dropdown if we can use pills.
- Detail: photo placeholder and Edit note bar match; site subtitle should be `customer · address`.
- Settings: structure matches; helper text already says device-only.

## Recruiter one-liner

Strong engineering core (offline-first, isolation, JOINs, tests). Would not yet submit: **no reachable backend, APK pointed at emulator localhost, incomplete Docker/README/design tokens, missing logo/font.** Fix packaging and UI polish; do not rewrite the sync stack.

## After polish (same day)

Addressed in this session without rewriting sync:

- `docs/ARCHITECTURE.md`, `docs/SYNC.md`, `docs/API.md`; `.gitignore` for keystores / APKs / `.env`
- `AppConfig` + `--dart-define=API_BASE_URL`; health `GET /api/health`; `server.address=0.0.0.0`
- `backend/Dockerfile` + Compose `db` + `backend`; host-scoped cleartext; `ACCESS_NETWORK_STATE`; local keystore via `key.properties` (not committed)
- Design tokens, bundled Plus Jakarta Sans, `field_notes_logo.svg`, launcher icons, `SyncPill` Failed · Retry, location clear, site address on detail
- Extra tests: health, coordinate validation, legacy global cursor ignored
- `flutter analyze` clean; `flutter test` 17 passed; `mvn test` 7 passed

Still for the candidate before 14 Oct 2026: **public HTTPS deploy**, **GitHub Release with APK**, **demo video**, **device walkthrough**, **screenshots in `docs/screenshots/`**.
