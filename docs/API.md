# API

Base URL is whatever the app is built with (`--dart-define=API_BASE_URL=...`). JSON, `Authorization: Bearer <accessToken>` on every route except auth and health.

Errors look like:

```json
{
  "timestamp": "2026-10-08T12:00:00Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Latitude and longitude must both be set",
  "path": "/api/notes/11111111-1111-1111-1111-111111111111"
}
```

Foreign IDs return **404**, not 403.

## Health

`GET /api/health` (also `/actuator/health`) → `{ "status": "UP" }`

Free-tier hosts may take 30–60 seconds to wake up.

## Auth

`POST /api/auth/register`

```json
{ "email": "worker@company.com", "password": "password123" }
```

`201` `{ "id": 1, "email": "worker@company.com" }` — duplicate email is `409`.

`POST /api/auth/login`

```json
{ "email": "worker@company.com", "password": "password123" }
```

`200` `{ "accessToken": "...", "refreshToken": "...", "expiresIn": 3600 }`

`POST /api/auth/refresh`

```json
{ "refreshToken": "..." }
```

## Customers

| Method | Path | Notes |
|---|---|---|
| GET | `/api/customers` | Current user's active customers |
| GET | `/api/customers/{id}` | 404 if missing or not yours |
| PUT | `/api/customers/{id}` | Upsert; `{id}` is the **client UUID** |
| DELETE | `/api/customers/{id}` | Soft-deletes customer, sites, and notes |

```json
{ "name": "Northwind Ltd", "contactInfo": "desk@northwind.test" }
```

## Sites

| Method | Path |
|---|---|
| GET | `/api/sites?customerId=` |
| GET | `/api/sites/{id}` |
| PUT | `/api/sites/{id}` |
| DELETE | `/api/sites/{id}` |

```json
{
  "customerId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "siteName": "Harbor Plaza",
  "address": "12 Dock Road"
}
```

`customerId` must belong to the same user or the API returns 404.

## Notes

| Method | Path |
|---|---|
| GET | `/api/notes?status=&siteId=&q=` |
| GET | `/api/notes/{id}` |
| PUT | `/api/notes/{id}` |
| DELETE | `/api/notes/{id}` |
| POST | `/api/notes/{id}/photo` multipart field `file` |
| GET | `/api/notes/{id}/photo` |

`q` is case-insensitive and matches title, description, site name, and customer name via `field_notes JOIN sites JOIN customers`. The JSON includes nested `site` and `customer` objects — names are not duplicated on the note row.

```json
{
  "siteId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
  "title": "Leaking valve, boiler room",
  "description": "Valve at joint B dripping; part ordered.",
  "latitude": 23.8103,
  "longitude": 90.4125,
  "notedAt": "2026-10-08T04:20:00Z",
  "status": "OPEN"
}
```

`status` is `OPEN`, `IN_PROGRESS`, or `COMPLETED`. Latitude must be in `-90..90`, longitude in `-180..180`. A half-filled pair is `400`.

## Sync

`POST /api/sync/push` — customers, then sites, then notes. Each item is upsert-by-UUID or a soft delete.

```json
{
  "customers": [
    {
      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "name": "Northwind Ltd",
      "contactInfo": null,
      "createdAt": "2026-10-08T04:00:00Z",
      "deleted": false
    }
  ],
  "sites": [],
  "notes": []
}
```

Response items: `{ "id", "status": "APPLIED"|"ERROR", "error", "updatedAt" }`.

`GET /api/sync/pull?since=1970-01-01T00:00:00Z` returns `{ customers, sites, notes, serverTime }` including soft-deleted rows (`deletedAt` set) so the client can drop them.
