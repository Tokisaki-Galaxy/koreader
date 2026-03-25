# Reading Statistics Serverless REST API

This document describes the serverless HTTP contract used by
`plugins/statistics.koplugin` when **Sync mode** is set to **Serverless API**.

The authentication model is intentionally aligned with KOReader progress sync
(`koreader-sync-serverless`):

- Header: `x-auth-user: <username>`
- Header: `x-auth-key: <userkey>`
- Accept: `application/vnd.koreader.v1+json`
- Content-Type: `application/json`

## 1) Synchronize statistics

### Endpoint

- `PUT /syncs/statistics`

### Headers

- `x-auth-user`: user name
- `x-auth-key`: user key (same key style as progress sync plugin)
- `accept`: `application/vnd.koreader.v1+json`
- `content-type`: `application/json`

### Request body

```json
{
  "schema_version": 20221111,
  "device": "KOReader Device Model",
  "device_id": "device-id-or-empty-string",
  "snapshot": "{\"books\":[...],\"page_stat_data\":[...]}"
}
```

Field details:

- `schema_version` (`integer`, required): client DB schema version.
- `device` (`string`, required): device display name/model.
- `device_id` (`string`, required): KOReader device id (empty string allowed).
- `snapshot` (`string`, required): JSON-encoded statistics snapshot.

`snapshot` payload structure:

```json
{
  "books": [
    {
      "id": 1,
      "title": "Book title",
      "authors": "Author",
      "notes": 0,
      "last_open": 1710000000,
      "highlights": 0,
      "pages": 320,
      "series": "Series #1",
      "language": "en",
      "md5": "partial-md5",
      "total_read_time": 1234,
      "total_read_pages": 88
    }
  ],
  "page_stat_data": [
    {
      "id_book": 1,
      "page": 12,
      "start_time": 1710000100,
      "duration": 24,
      "total_pages": 320
    }
  ]
}
```

### Success responses

- `200 OK`
- `202 Accepted`

Recommended response body:

```json
{
  "ok": true,
  "snapshot": "{\"books\":[...],\"page_stat_data\":[...]}"
}
```

If `snapshot` is returned, KOReader will replace local `book` and
`page_stat_data` with it atomically.

### Error responses

- `401 Unauthorized` (invalid `x-auth-user` / `x-auth-key`)
- `400 Bad Request` (invalid payload)
- `413 Payload Too Large` (snapshot too large; server policy)
- `500 Internal Server Error`

Recommended error body:

```json
{
  "message": "human readable error"
}
```

## Server merge policy (recommended)

For compatibility and predictable client behavior:

1. Authenticate by `x-auth-user` + `x-auth-key`.
2. Parse request `snapshot`.
3. Merge server-side and client-side data (or pick latest authoritative state).
4. Return merged canonical snapshot in response `snapshot`.

This keeps the client implementation simple while allowing server-side conflict
resolution that fits a serverless database backend (e.g., Cloudflare D1).
