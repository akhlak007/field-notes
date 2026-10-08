# Field Notes Completion and UI Design

## Purpose

Bring the existing Field Notes Flutter and Spring Boot implementation to submission-ready quality without replacing its working offline-first architecture. The work fixes the identified restore and sync-state gaps, improves validation and recovery feedback, and applies a cohesive professional field-service interface.

## Scope

### Functional completion

- Store the synchronization cursor per authenticated user instead of globally.
- Ensure signing out and subsequently signing in as another account cannot reuse another user's pull cursor or access another user's local rows.
- Scope all local reads, writes, pending queues, and destructive operations to the authenticated user. A pending change owned by user A must never be selected or pushed while user B is authenticated.
- Preserve pending local changes after sign-out and after a refresh-token failure so the same account can resume them later.
- Warn before a deliberate sign-out when the current account has pending local changes; do not silently discard them.
- Reset session-specific sync state when authentication changes.
- Preserve automatic sync on launch, local changes, connectivity restoration, and manual refresh.
- Surface sync failures in the UI with a concise message and retry action while retaining queued local changes.
- Validate latitude and longitude ranges before saving a local note.
- Preserve existing customer, site, note, photo, permission, search, filter, and local-settings behavior.

### Professional UI refresh

- Keep Material 3 and the existing teal field-service identity, but introduce a deliberate color system, typography hierarchy, component shapes, spacing, and elevation.
- Redesign authentication as a branded, responsive welcome surface with clearer mode switching and form affordances.
- Give the main shell a consistent background, polished sync status, and refined navigation.
- Present notes, customers, and sites as information-rich cards with leading visual cues, metadata, status badges, and clear tap targets.
- Improve empty, loading, offline, error, and destructive-confirmation states.
- Group form fields into readable sections, add helper copy and icons, constrain form width on large displays, and make primary actions prominent.
- Improve note detail hierarchy, photo presentation, location display, and status/date metadata.
- Improve Settings with account, default-status, synchronization, and sign-out sections.
- Support light and dark themes and remain usable at mobile and desktop widths.

## Architecture

The existing layering remains unchanged:

`Widget -> BLoC -> Repository -> local SQLite database -> SyncService -> REST API`

The local database remains the UI source of truth. UI changes must not add network calls to widgets or BLoCs. The API, relational schema, client-generated UUIDs, soft deletion, and push-before-pull synchronization strategy remain in place.

### Per-user synchronization cursor

`AppDatabase.lastSyncAt` and `setLastSyncAt` will accept a user ID and use a key such as `last_sync_at:<userId>`. `SyncService` will read and update only the current user's cursor. Existing unscoped cursor data will be ignored so each account performs one safe full pull after the upgrade.

### Cross-account local isolation

Local rows remain retained across sign-out so pending offline work is recoverable, but every lookup, mutation, cascade, photo operation, pending-count query, and sync selection must include the active `userId`. Repository methods that address a row by ID will require the user ID and reject rows owned by another account. Because UUIDs are globally unique, the database schema does not need to duplicate primary keys; ownership enforcement occurs in every query boundary.

When another account signs in, existing streams will be rebound to the new user and the sync session will be reset before the new user's first sync. The new token can only push rows selected by that new user's ID. No automatic clearing occurs, preventing loss of user A's pending work. A deliberate sign-out with pending changes requires confirmation that explains those changes will remain on the device until that account returns.

### Session transitions

`SyncBloc` will support stopping or resetting its current session when the user becomes unauthenticated. Retry timers will be cancelled, the user ID cleared, and visible state returned to an idle state. Starting a new authenticated session will calculate its own pending count and trigger an initial pull when online.

A 401 that cannot be recovered by refreshing credentials triggers this same reset and returns to authentication, while leaving the account's local rows and pending queue intact.

### Sync failure feedback

`SyncState` will carry a non-sensitive failure message in addition to online, syncing, and pending values. A failed attempt keeps local changes pending, schedules the existing backoff retry, and displays an actionable banner. Manual retry clears the old message while a new attempt runs.

### Validation

The note BLoC will reject incomplete coordinate pairs and enforce latitude `-90..90` and longitude `-180..180` before the note is written locally. Backend validation remains the final authority.

## Components

### Theme and shared UI

- Expand `AppTheme` with consistent surface colors, navigation, app bars, cards, buttons, fields, chips, dialogs, and text styles.
- Add reusable presentation components for page headers, section cards, status badges, metadata rows, list cards, responsive content constraints, empty states, and sync status.
- Keep components focused on presentation; domain behavior remains in feature BLoCs.

### Authentication

- Brand mark and concise value statement.
- Contained credential card with icons, password visibility toggles, keyboard submission, and inline error treatment.
- Clear sign-in/register mode switch without losing entered email.

### Notes

- Header with page purpose and new-note action.
- Search and filters presented as a coherent control panel.
- Note cards showing status, customer/site, timestamp, and a description preview.
- Detail screen using grouped metadata, prominent title/status, readable description, and rounded photo treatment.
- Form organized into site, content, status/time, location, and photo sections.

### Customers and sites

- Customer cards showing contact context and site affordance.
- Customer and site details use summary cards plus clearly separated related records.
- Add/edit forms share the responsive section-card pattern.

### Settings

- Account identity card.
- Default status selector with explanatory copy and visual status indicators.
- Sync guidance and a distinct, safely styled sign-out action.

## Data and error flow

- Local writes remain immediate and notify the change bus.
- Synchronization success updates local records and pending counts.
- Item-level server rejections remain queued; the sync layer exposes a general actionable failure without leaking server internals.
- Network failure never discards local changes or blocks local CRUD.
- Authentication expiry signs the user out and resets session-specific sync state.
- Permission denial continues to allow saving notes without location or photos and offers system settings only for permanently denied permissions.

## Testing and verification

### Flutter tests

- Existing search, push/pull, deletion, and settings tests remain green.
- Add coverage for per-user sync cursor isolation.
- Add a cross-account sequence test: user A creates pending data, signs out, user B signs in, user B sees none of A's data, and user B's sync request contains none of A's pending changes.
- Add coordinate-range validation tests.
- Add SyncBloc coverage proving a failed sync keeps rows pending and a later retry succeeds, plus session reset behavior.
- Add targeted widget tests for professional empty states and sync error/retry presentation.

### Backend tests

- Compile with Maven.
- Run the Testcontainers integration suite with sufficient startup time.
- Preserve authentication, isolation, relational join, cascading soft-delete, sync idempotency, and photo tests.

### Quality gates

- `flutter analyze`
- `flutter test`
- Flutter production build for an available target
- `mvn test`
- Review changed screens for clipping, overflow, contrast, light/dark consistency, and narrow/wide layouts.

Functional fixes and their tests are completed first. The UI refresh starts only after `flutter test` and `mvn test` pass. If delivery time becomes constrained, UI polish may be reduced, but the isolation, cursor, session, failure-feedback, and validation fixes remain mandatory.

## Non-goals

- No teams, roles, maps, notifications, web-specific client, or new backend service.
- No synchronization-protocol rewrite.
- No database normalization changes beyond the client-side cursor key.
- No removal of existing functionality or submitted data.

## Completion criteria

The work is complete when every assignment requirement is represented by working code, the known cross-account restore defect is fixed, sync failures are recoverable and understandable, validation prevents permanently invalid queued locations, the UI is consistently professional across the main flows, and all available automated checks and builds pass.
