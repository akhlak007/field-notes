# Architecture

Field Notes is an offline-first field-worker app. The phone is usable without a network. The server is a per-user source of truth that the device catches up with later.

```
  ┌─────────────┐
  │   Widget    │  reads BLoC state only
  └──────┬──────┘
         ▼
  ┌─────────────┐
  │    BLoC     │  auth, notes, customers, sites, settings, sync
  └──────┬──────┘
         ▼
  ┌─────────────┐
  │ Repository  │  maps Drift rows ↔ domain models
  └──────┬──────┘
         ▼
  ┌─────────────┐     LocalChangeBus      ┌─────────────┐
  │ local SQLite│ ──────────────────────► │ SyncService │
  │   (Drift)   │                         └──────┬──────┘
  └─────────────┘                                ▼
                                          ┌─────────────┐
                                          │  REST API   │  Spring Boot
                                          └──────┬──────┘
                                                 ▼
                                          ┌─────────────┐
                                          │ PostgreSQL  │  Flyway schema
                                          └─────────────┘
```

## Layers

| Layer | What lives here | Rule |
|---|---|---|
| Widgets (`features/*/`, `shared/widgets/`) | Screens and reusable UI | No `Dio`, no SQL. |
| BLoC | Auth, CRUD, filters, permission requests, sync status | Talks to repositories / `SyncService`. |
| Repository | Drift writes, search JOINs, photo copy | Local DB first. Mark `pending_upsert` / `pending_delete`. |
| Local SQLite | Customers, sites, notes, `sync_meta` | UI source of truth. Rows are scoped by `user_id`. |
| SyncService | Push pending → upload photos → pull since cursor | Per-user cursor `last_sync_at:<userId>`. |
| REST + JPA | Auth, CRUD, JOIN search, batch sync | Every query uses the JWT user id. Foreign UUIDs return 404. |

Settings (default note status) is SharedPreferences on the device. It is never written to SQLite sync tables or sent to the API.

## Why SQLite (Drift) instead of Hive

Search must match title, description, site name, and customer name together with status/site filters. That is a JOIN. The local schema mirrors the server: FKs only, no copied names on note rows.
