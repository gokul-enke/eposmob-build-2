# Realtime Sync — Backend Test Report and Action Request

Hi Backend Team,

We tested the Flutter POS integration against the demo backend on **29 July
2026**. The core Laravel Reverb contract is working end to end. This document
records what passed, the public client configuration that worked, and the
remaining backend checks needed before production rollout.

> No tenant key, bearer token, Reverb secret, or private auth signature is
> included in this document.

---

## Test environment

- Backend: `https://eposdemo.yougoit.in`
- Company ID used for validation: `2`
- Private channel: `private-company.2.sync`
- Raw Pusher event expected by Flutter: `data.changed`
- Client: raw Pusher protocol over Dart `web_socket_channel`

## Confirmed public Reverb connection

The externally reachable Reverb URL is:

```text
wss://eposdemo.yougoit.in/app/{REVERB_APP_KEY}
    ?protocol=7
    &client=flutter
    &version=1.0
```

Effective external client settings:

```text
REVERB_HOST=eposdemo.yougoit.in
REVERB_PORT=443
REVERB_SCHEME=https / WebSocket scheme wss
```

The server-side `127.0.0.1:8081` values are internal Reverb listener settings.
They must not be supplied to remote Flutter clients.

Direct public access to:

```text
ws(s)://eposdemo.yougoit.in:8081
```

timed out during testing. This is acceptable because Caddy/Cloudflare is
successfully exposing Reverb through secure WebSocket port `443`.

Please document port `443`/`wss` as the Flutter production connection, rather
than public port `8081`.

---

## End-to-end results

| Check | Result |
|---|---|
| DNS and HTTPS port `443` | Pass |
| Secure WebSocket upgrade | Pass |
| `pusher:connection_established` received | Pass |
| `socket_id` returned | Pass |
| `POST /api/broadcasting/auth` with `X-Tenant` | Pass |
| Private-channel auth token returned | Pass |
| Subscribe to `private-company.2.sync` | Pass |
| `pusher_internal:subscription_succeeded` | Pass |
| `GET /api/v1/sync/changes?since=` | Pass |
| Expected `success`, `synced_at`, and entity groups | Pass |
| Live `data.changed` event | Not exercised because no record was edited during the 20-second listener window |

The complete connection/auth/subscription/pull sequence passed.

## Initial pull result

Calling `/api/v1/sync/changes` with an empty `since` returned:

```text
synced_at: 2026-07-29T06:09:25+00:00

customers: 203 upserted, 7 deleted
products:  4786 upserted, 4040 deleted
stocks:    5297 upserted, 35 deleted
```

Large counts are expected for an empty `since`, but the response is large
enough that the initial-seed strategy should be confirmed. Flutter plans to use
the existing bulk/list APIs for initial store bootstrap, then use the server
cursor for incremental catch-up.

---

## Backend actions/checks requested

### 1. Verify tenant authorization on `/sync/changes`

During a route probe, this request returned `200` and change data without an
`X-Tenant` header:

```http
GET /api/v1/sync/changes?since=
```

The documented contract says `X-Tenant` is required. Please confirm that:

- a missing `X-Tenant` returns `401`;
- an invalid tenant key returns `401`;
- a valid tenant key can only read that tenant's company data;
- no default/fallback company is selected when the header is missing.

This is the most important issue to resolve before production because the
response exposes record IDs and deletion history.

### 2. Run one live event test

While a Flutter/client listener is subscribed to:

```text
private-company.2.sync
```

please create or update one record in each relevant model:

- Customer
- Product
- ProductStock

For each change, confirm the client receives:

```json
{
  "event": "data.changed",
  "channel": "private-company.2.sync",
  "data": {
    "entity": "product",
    "action": "updated",
    "id": 4242,
    "company_id": 2,
    "changed_at": "..."
  }
}
```

The exact `entity`, `action`, and `id` values will vary. With raw Pusher
protocol, Flutter matches the literal event name `data.changed`; the leading
dot form `.data.changed` applies only to Laravel Echo listeners.

Also verify:

- `php artisan queue:work` is running;
- `php artisan reverb:start` is running;
- queued broadcast failures are monitored;
- event delivery is not delayed by a stopped database queue worker.

### 3. Verify tenant isolation in broadcast auth

Please add or confirm tests for:

- valid company API key + matching company channel -> auth succeeds;
- valid company API key + another company channel -> `403`;
- missing tenant key -> `401`;
- invalid tenant key -> `401`;
- malformed `socket_id` or channel -> rejected.

The Reverb app secret must remain backend-only.

### 4. Confirm stable cursor-window behavior

`/sync/changes` should:

1. capture a server-side cutoff timestamp;
2. query records changed after `since` and at or before that cutoff;
3. return the same cutoff as `synced_at`.

Conceptually:

```text
since < changed_at <= synced_at
```

Flutter will persist only the returned `synced_at` and use it for the next
request. Please confirm concurrent updates cannot fall between the query and
the returned cursor.

### 5. Confirm deletion tracking

Please verify that soft-deleted IDs are reported incrementally for:

- customers;
- products;
- product stocks.

If any of these models can be hard-deleted, a tombstone/change-log table is
required because a hard-deleted row cannot be discovered from its original
table on a later pull.

### 6. Confirm store behavior

The Reverb channel is company-scoped, while the Flutter POS is store-scoped.
Please document:

- whether product and customer changes are company-wide or store-specific;
- whether stock change payloads can include `store_id`;
- whether existing record/list endpoints filter changed IDs by the active
  `store_id`;
- whether `/sync/changes` should accept an optional `store_id`.

A company-wide notification is acceptable, but subsequent Flutter fetches must
not apply stock from another store.

### 7. Confirm changed-record fetch strategy

`/sync/changes` returns IDs only. Please identify the supported endpoints for
fetching full records by ID in batches:

```text
products:  [...]
customers: [...]
stocks:    [...]
```

If no batch-by-ID endpoints exist, Flutter's first release will use:

```text
product change  -> existing product delta refresh
customer change -> existing full customer refresh
stock change    -> existing full stock + product refresh
```

That is correct but less efficient. Bulk-by-ID endpoints are recommended for
larger tenants and many simultaneously connected POS devices.

### 8. Consider an initial checkpoint endpoint

An empty `since` currently returns thousands of IDs. A lightweight checkpoint
would let Flutter:

1. obtain a server cursor;
2. complete its existing paginated initial store bootstrap;
3. call `/sync/changes` from that cursor to recover changes made during the
   bootstrap.

Possible response:

```json
{
  "success": true,
  "synced_at": "2026-07-29T06:09:25+00:00"
}
```

This is an optimization, not a blocker for the current test implementation.

---

## Expected contract for Flutter

### Private-channel authorization

```http
POST /api/broadcasting/auth
X-Tenant: {company_api_key}
Content-Type: application/json

{
  "socket_id": "{socket_id}",
  "channel_name": "private-company.{companyId}.sync"
}
```

Successful response:

```json
{
  "auth": "{REVERB_APP_KEY}:{server_generated_signature}"
}
```

### Incremental change pull

```http
GET /api/v1/sync/changes?since={url_encoded_server_synced_at}
X-Tenant: {company_api_key}
Accept: application/json
```

Successful response:

```json
{
  "success": true,
  "synced_at": "2026-07-29T06:09:25+00:00",
  "changes": {
    "customers": {
      "upserted": [],
      "deleted": []
    },
    "products": {
      "upserted": [],
      "deleted": []
    },
    "stocks": {
      "upserted": [],
      "deleted": []
    }
  }
}
```

---

## Summary

The following backend pieces are confirmed working:

- secure Reverb endpoint through port `443`;
- Pusher connection handshake;
- tenant-authorized private channel;
- company channel subscription;
- incremental change response shape.

Before production, please:

1. fix or explain why `/sync/changes` returns data without `X-Tenant`;
2. run live Customer/Product/ProductStock event tests;
3. confirm cursor-window and deletion correctness;
4. document store filtering and record-fetch endpoints;
5. document `wss://{tenant-host}:443`, not public port `8081`, for Flutter.

Once these checks are complete, Flutter can proceed from the temporary
diagnostic page to application-wide synchronization.
