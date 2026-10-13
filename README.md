# Field Notes

Offline-first notes for field workers. The phone keeps customers, sites, and notes in local SQLite and syncs them with a Spring Boot API when a connection is available. Built for the ATI Limited Mobile Apps take-home (Flutter + BLoC, Drift/SQLite, Spring Boot, PostgreSQL, JWT, JOIN search, offline sync).

## Features

- Register / sign in with JWT; data is isolated per account (foreign IDs return 404)
- Customers → sites → notes, stored as foreign keys only (names come from JOINs)
- Create, edit, and delete while offline; auto-sync when the network returns
- Search notes by title, description, site, or customer; filter by status and site
- Photo (camera or gallery) and current location, with a non-crashing denied path
- Default note status in Settings — saved on this device only, never synced
- Restore after clear-data / reinstall by signing in again (pull from epoch)

## Architecture

```
Widget → BLoC → Repository → local SQLite (Drift) → SyncService → REST API
```

Local SQLite is the UI source of truth. Sync is **push pending rows, then pull since a per-user cursor** (`last_sync_at:<userId>`). Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/SYNC.md](docs/SYNC.md), [docs/API.md](docs/API.md).

## Tech stack

| Side | Stack |
|---|---|
| Mobile | Flutter, BLoC, Drift/SQLite, Dio, SharedPreferences |
| Backend | Java 17, Spring Boot 3.5, Spring Security + JWT, JPA, Flyway, PostgreSQL 16 |

## Deployment (public HTTPS + APK)

Target: **PostgreSQL on Neon** + **Spring Boot on Render** (Docker) + release APK compiled with the Render URL.

| Item | Value |
|---|---|
| **Live backend URL** | `https://field-notes-3.onrender.com` |
| **Health** | `GET https://field-notes-3.onrender.com/api/health` → `{"status":"UP"}` |
| **APK** | From the repo root: `.\scripts\build-release-apk.ps1` — the release APK already talks to the public URL. Attach `mobile/build/app/outputs/flutter-apk/FieldNotes-v1.0.apk` to a GitHub Release |
| **Demo account** | Register in the app, or create `worker@company.com` / `password123` once via the API |
| **Wake-up** | Render **free** web services sleep after ~15 minutes idle and can take **30–60 seconds** to wake. The first request is slow; it is not a crash. Check [Render pricing](https://render.com/pricing) for current free-tier terms. |

Render env vars (never commit the real values):

| Name | Example |
|---|---|
| `SPRING_PROFILES_ACTIVE` | `prod` |
| `PORT` | `8080` |
| `SERVER_ADDRESS` | `0.0.0.0` |
| `DB_URL` | `jdbc:postgresql://<neon-host>/<db>?sslmode=require` |
| `DB_USER` | Neon user |
| `DB_PASSWORD` | Neon password |
| `JWT_SECRET` | output of `openssl rand -base64 48` (32+ bytes) |
| `PHOTO_DIR` | `/app/uploads` |

Photos are files under `PHOTO_DIR`. On free Render disks they **disappear when the instance restarts**. Notes and other data stay in Neon. CORS is off; a mobile app does not need it.

Release APKs use HTTPS only (`usesCleartextTraffic` is not set on the main manifest). If `mobile/android/key.properties` is missing, Gradle signs the release APK with the **debug** keystore (fine for this take-home).

### LAN fallback (your phone on home Wi-Fi)

Use a **debug** build; release blocks arbitrary LAN HTTP:

```powershell
docker compose up --build
cd mobile
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080
```

## Run locally

**Docker (database + API):**

```bash
docker compose up --build
```

API: `http://localhost:8080` — `GET /api/health` should return `{ "status": "UP" }`.

**Without Docker for the API** (Postgres still from Compose):

```powershell
docker compose up -d db
cd backend
.\mvnw.cmd spring-boot:run
```

```bash
docker compose up -d db
cd backend
./mvnw spring-boot:run
```

| Variable | Default |
|---|---|
| `PORT` | `8080` |
| `SERVER_ADDRESS` | `0.0.0.0` |
| `DB_URL` | `jdbc:postgresql://localhost:5432/fieldnotes` |
| `DB_USER` / `DB_PASSWORD` | `fieldnotes` |
| `JWT_SECRET` | Optional locally: omitted values generate an ephemeral random key. Set a random 32+ byte value to keep sessions valid across restarts; required in production. |

Copy `.env.example` to `.env` for local overrides. Never commit `.env` or keystores.

Windows one-shot (Postgres + API + Flutter desktop): `.\run.ps1`. macOS/Linux: `./run.sh`.

## How to run / build the mobile app

```bash
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

| Target | `API_BASE_URL` |
|---|---|
| Windows / macOS / iOS simulator | `http://localhost:8080` |
| Android emulator | `http://10.0.2.2:8080` (this is the Android default if the define is omitted) |
| Physical phone | `http://<laptop-ip>:8080` (debug) or `https://<public-api>` (release) |

**Release APK** (public API is baked in — no URL flag required):

```powershell
.\scripts\build-release-apk.ps1
```

Output: `mobile/build/app/outputs/flutter-apk/FieldNotes-v1.0.apk`. If `mobile/android/key.properties` is missing, Gradle signs with the debug keystore (fine for this take-home).

## How sync works (five lines)

1. Every create/edit/delete writes SQLite immediately and is marked pending.
2. Sync pushes customers, then sites, then notes, then photos.
3. Sync then pulls changes newer than `last_sync_at:<userId>`.
4. Soft deletes travel through pull so other devices drop the row; last-write-wins, local pending is not overwritten.
5. Sync runs on launch, after a local change, when connectivity returns, and on Retry / pull-to-refresh.

## Checks actually run (13 Oct 2026)

| Command | Result |
|---|---|
| `flutter analyze` (in `mobile/`) | No issues found |
| `flutter test` | All 24 tests passed |
| `mvn test` (`backend/mvnw.cmd test`) | 8 tests, 0 failures (Testcontainers + PostgreSQL 16), including concurrent sync locking |
| `.\scripts\build-release-apk.ps1` | Built `FieldNotes-v1.0.apk` (65.0MB) pointed at `https://field-notes-3.onrender.com` |
| Install on a physical phone against a public API | **Not run on a device here**; the public health endpoint was verified `UP` and the APK contains the live hostname |
| Airplane-mode create → reconnect → restore after clear data | **Not run on a device here**; covered by unit tests for cursor isolation, pending push, and pull restore |
| Demo video | **Not recorded** |

## Known limitations

- The public API is `https://field-notes-3.onrender.com`; Flyway creates tables on the first successful boot against Neon.
- Release HTTP is not open to arbitrary LAN IPs; prefer HTTPS or a debug build for Wi-Fi demos.
- Default note status is device-wide SharedPreferences (by design: “saved on this device only”), not synced.
- Photos are stored on the API filesystem (`PHOTO_DIR`). On free Render they can vanish on restart; metadata stays in Postgres.

## Screenshots

See [docs/screenshots/](docs/screenshots/). Capture sign-in, notes list, note detail, new note, customers, and settings from the running app.

## Recruiter audit

[docs/AUDIT.md](docs/AUDIT.md) is the 15-minute hiring-engineer pass taken **before** polish, plus a short after-polish note.
