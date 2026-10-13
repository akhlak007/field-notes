# Sync

The local database is what the UI shows. The network is a background catch-up.

## Outbox

Every create, edit, or delete writes SQLite immediately:

- `sync_state = pending_upsert` for inserts and edits
- `sync_state = pending_delete` for deletes (row stays, hidden from lists, until the server confirms)

Settings are not in the outbox.

## Push then pull

1. Collect this user's pending customers, then sites, then notes (FK order).
2. `POST /api/sync/push` as one batch. The server upserts by client UUID, sets `updated_at` itself, and returns per-item `APPLIED` / `ERROR`. One bad row does not roll back the others.
3. Upload pending photos (`POST /api/notes/{id}/photo`).
4. `GET /api/sync/pull?since=<cursor>`.
5. Apply remote rows unless the local row is still pending (local pending wins).
6. Store the server's `serverTime` as `last_sync_at:<userId>`.

Push acknowledgements are conditional on the exact local timestamp and pending
state that was sent. If the user edits, deletes, or replaces a photo while the
request is in flight, the older response cannot mark that newer change synced;
the newer version stays in the outbox for the next pass.

A leftover global `last_sync_at` key is ignored and deleted.

## Soft delete

Deletes set `deleted_at` on the server. Pull includes those rows so other devices can drop them. After the server applies a pending delete, the client removes the local row.

Deleting a customer soft-deletes its sites and notes in one transaction. Deleting a site soft-deletes its notes.

## Per-user cursor

The pull cursor is `last_sync_at:<userId>` in `sync_meta`. Two accounts on one phone do not share a cursor. Pending queries always filter by `user_id`, so user B never uploads user A's outbox.

## Last-write-wins

- Push: the server overwrites the stored row for that UUID (idempotent).
- Pull: if the local row is still `pending_*`, the remote change is skipped until that outbox item is applied.
- `updated_at` is assigned by the server.

PostgreSQL transaction-scoped advisory locking serializes entity mutations with
incremental pull snapshots. Pull cannot advance `serverTime` past a write that
has an earlier timestamp but has not committed yet.

## When sync runs

On launch after sign-in, after every local change, when connectivity returns, and on pull-to-refresh / Retry. A request received during an active pass is coalesced into one follow-up pass instead of being dropped. Failures keep the outbox and show **Failed · Retry**. Exponential backoff retries while the same user stays signed in. Sign-out cancels the timer.

A 401 after a failed refresh signs the session out but does **not** wipe SQLite. The same account can sign back in and push the leftover pending rows.
