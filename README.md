# Field Notes

<p align="center">
  <img src="docs/screenshots/field-notes-brand.png" alt="Field Notes brand and app icon" width="760" />
</p>

<p align="center"><strong>Capture every site. Even offline.</strong></p>

<p align="center">
  <a href="https://youtu.be/3YPGbu-IQuc">Video demo</a> ·
  <a href="https://field-notes-3.onrender.com/api/health">Live API</a> ·
  <a href="docs/ARCHITECTURE.md">Architecture</a> ·
  <a href="docs/API.md">API reference</a>
</p>

An offline-first mobile app for recording field observations during site visits. Customers, sites, and notes are written to local SQLite immediately and synchronized with a Spring Boot API whenever connectivity is available.

## Features

- Register / sign in with JWT; data is isolated per account (foreign IDs return 404)
- Customers → sites → notes, stored as foreign keys only (names come from JOINs)
- Create, edit, and delete while offline; auto-sync when the network returns
- Search notes by title, description, site, or customer; filter by status and site
- Photo (camera or gallery) and current location, with a non-crashing denied path
- Default note status in Settings — saved on this device only, never synced
- Restore after clear-data / reinstall by signing in again (pull from epoch)

## Demo

**[Watch the Field Notes app demo on YouTube](https://youtu.be/3YPGbu-IQuc)**

The written [demo walkthrough](docs/DEMO.md) covers registration, relational CRUD, search and filtering, offline changes, automatic synchronization, and server restore.

## Screenshots

<table>
  <tr>
    <th>Sign in</th>
    <th>Notes</th>
    <th>New note</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/sign-in.png" alt="Field Notes sign-in screen" width="240" /></td>
    <td><img src="docs/screenshots/notes-list.png" alt="Searchable and filterable notes list" width="240" /></td>
    <td><img src="docs/screenshots/new-note.png" alt="New field note form" width="240" /></td>
  </tr>
  <tr>
    <th>Note detail</th>
    <th>Customers</th>
    <th>Settings</th>
  </tr>
  <tr>
    <td><img src="docs/screenshots/note-detail.png" alt="Field note detail screen" width="240" /></td>
    <td><img src="docs/screenshots/customers.png" alt="Customer list with site counts" width="240" /></td>
    <td><img src="docs/screenshots/settings.png" alt="Settings and default note status" width="240" /></td>
  </tr>
</table>

## Architecture

```
Widget → BLoC → Repository → local SQLite (Drift) → SyncService → REST API
```

Local SQLite is the UI source of truth. Sync is **push pending rows, then pull since a per-user cursor** (`last_sync_at:<userId>`). Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/SYNC.md](docs/SYNC.md), [docs/API.md](docs/API.md).

The mobile app uses feature-based presentation with BLoC state management, repositories for local-first persistence, and a dedicated synchronization service. The backend separates controllers, services, repositories, security, DTOs, and relational entities.

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
| **Video demo** | [Watch on YouTube](https://youtu.be/3YPGbu-IQuc) |
| **Demo access** | Create an account from the Register tab; no shared credentials are required |
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

Release APKs use HTTPS only (`usesCleartextTraffic` is not set on the main manifest). A local release keystore can be configured with `mobile/android/key.properties`; this file and all keystores are ignored by Git.

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

Output: `mobile/build/app/outputs/flutter-apk/FieldNotes-v1.0.apk`.

## How sync works (five lines)

1. Every create/edit/delete writes SQLite immediately and is marked pending.
2. Sync pushes customers, then sites, then notes, then photos.
3. Sync then pulls changes newer than `last_sync_at:<userId>`.
4. Soft deletes travel through pull so other devices drop the row; last-write-wins, local pending is not overwritten.
5. Sync runs on launch, after a local change, when connectivity returns, and on Retry / pull-to-refresh.

## Verification

| Command | Result |
|---|---|
| `flutter analyze` (in `mobile/`) | No issues found |
| `flutter test` | All 29 tests passed |
| `mvn test` (`backend/mvnw.cmd test`) | 8 tests, 0 failures (Testcontainers + PostgreSQL 16), including concurrent sync locking |
| `.\scripts\build-release-apk.ps1` | Built `FieldNotes-v1.0.apk` (65.0MB) pointed at `https://field-notes-3.onrender.com` |

## Known limitations

- The public API is `https://field-notes-3.onrender.com`; Flyway creates tables on the first successful boot against Neon.
- Release HTTP is not open to arbitrary LAN IPs; prefer HTTPS or a debug build for Wi-Fi demos.
- Default note status is device-wide SharedPreferences (by design: “saved on this device only”), not synced.
- Photos are stored on the API filesystem (`PHOTO_DIR`). On free Render they can vanish on restart; metadata stays in Postgres.
