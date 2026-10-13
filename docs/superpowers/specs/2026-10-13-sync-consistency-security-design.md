# Sync Consistency and Security Design

## Purpose

Close the concurrency and development-security gaps found during the final Field Notes audit without changing the public REST payloads, offline-first user experience, or relational data model.

## Scope

- Prevent a push response from acknowledging a newer local edit or delete that was not included in that push.
- Ensure a local change raised while synchronization is already running triggers another synchronization pass.
- Prevent incremental pull from advancing its cursor past a concurrently committing database write.
- Stop local/default deployments from using a publicly forgeable JWT signing secret while retaining a one-command local setup.
- Add deterministic regression coverage for each corrected race or configuration rule.
- Rebuild and revalidate the Android release artifact.

The suspended Render service and its account state are outside the codebase. The repository will remain deployable, but resuming or replacing that service requires owner credentials.

## Client Push Acknowledgements

Each pending row snapshot already contains its local `updatedAt` and `syncState`. A successful server result will acknowledge that exact snapshot only. Database acknowledgement and removal methods will add predicates for the expected timestamp and sync state:

- A create/update is marked synced only when the current row still has the snapshot's `updatedAt` and pending-upsert state.
- A delete is physically removed only when the current row still has the snapshot's `updatedAt` and pending-delete state.
- If the row changed while the request was in flight, the conditional operation affects zero rows. The newer row remains pending and is sent by a later pass.
- Photo acknowledgement will likewise require the local photo path and pending-photo state captured before upload, so replacing a photo during upload cannot acknowledge the replacement.

The server response timestamp may replace the local `updatedAt` only after the conditional match succeeds.

## Client Sync Scheduling

`SyncBloc` will remember a sync request received while another request is running. After a pass finishes, it will refresh the pending count and enqueue one follow-up pass when either the rerun flag is set or pending work remains. The flag is reset on session stop and user changes. Existing retry/backoff behavior remains unchanged.

This makes the scheduler coalesce repeated events without dropping them or creating concurrent sync passes.

## Server Pull Consistency

The REST cursor remains an ISO-8601 timestamp, avoiding a breaking mobile/API migration. PostgreSQL transaction-scoped advisory locking will serialize cursor-sensitive writes with pull snapshots:

- A small database lock component obtains one fixed `pg_advisory_xact_lock` inside the current transaction.
- Every customer, site, note, and photo mutation obtains the lock before assigning `updatedAt` or changing durable state.
- Pull runs in one transaction, obtains the same lock, records `serverTime`, and executes all three changed-since queries while holding the lock.
- A writer that started earlier must commit before pull can acquire the lock. A writer that starts later waits until pull commits and receives an `updatedAt` later than the returned cursor.

The lock is database-wide for this take-home application. It favors correctness and a small patch over a new change-log/cursor protocol. PostgreSQL is already a required backend, so this does not introduce a new platform dependency.

## JWT Defaults

Production continues to require `JWT_SECRET`. For local development, the application will generate a strong random signing secret at startup when no environment secret is supplied, rather than using a committed known value. Docker Compose will no longer inject the known fallback. Tokens will naturally become invalid after a local process/container restart unless the developer supplies `JWT_SECRET`, which is acceptable and will be documented.

The production startup guard remains defense in depth and rejects weak or placeholder secrets.

## Photo Durability

Photo persistence is not changed in this patch. The current Render service has no attached durable disk, and adding one can incur account cost and still requires owner action. The README will continue to state this limitation. A later deployment decision can attach a persistent disk at `PHOTO_DIR` or move photo bytes to object storage without changing note relationships.

## Error Handling and Compatibility

- Conditional acknowledgement misses are not errors; they indicate a newer local version and leave it queued.
- Advisory-lock SQL failure fails the transaction and surfaces through the existing API error handling.
- Existing clients and REST request/response schemas remain compatible.
- Offline writes remain immediate and never wait for the server lock.

## Verification

- Flutter database/sync test: edit a row inside the fake push callback and prove the push response cannot mark the newer row synced.
- Flutter database/sync test: replace a pending photo during upload and prove the replacement remains pending.
- SyncBloc test: request sync during an active pass and prove a second pass runs.
- Backend integration test: verify the pull endpoint and all mutation paths continue to pass against PostgreSQL.
- Configuration test: boot without `JWT_SECRET` and confirm a non-placeholder secret; production boot without a secret must fail.
- Run `flutter analyze`, `flutter test`, Maven tests, both Docker builds, local API smoke tests, and the release APK build/signature inspection.

## Completion Criteria

The change is complete when newer local edits cannot be acknowledged by an older request, sync events cannot be dropped while a pass is active, pull cannot skip a write across its returned cursor, default deployments no longer share a known JWT key, all regression suites pass, and the rebuilt APK is valid. Online APK behavior remains blocked until the Render owner resumes or replaces the suspended service.
