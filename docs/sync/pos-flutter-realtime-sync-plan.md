# Flutter POS — Real-Time Sync Implementation Plan

How the Flutter POS app consumes real-time data changes (products, customers,
stock) pushed from the Enke backend over **Laravel Reverb** (Pusher WebSocket
protocol).

---

## 1. The contract (what the backend already provides)

The backend side is live. The POS is a thin client against this contract.

| Piece | Value |
|---|---|
| WebSocket server | Reverb — running on **port `8081`** on the server (`prod: <public host>`, `wss` behind proxy or direct `ws://<host>:8081`) |
| App key (public, shippable) | `REVERB_APP_KEY` — e.g. `974c4a791ed462631fd0` |
| Auth endpoint | `POST {BACKEND}/api/broadcasting/auth` — header `X-Tenant: <company api_key>` |
| Channel | `private-company.{companyId}.sync` |
| Event name (`broadcastAs`) | `data.changed` — **subscribe as `.data.changed` (leading dot)** |
| Pull endpoint | `GET {BACKEND}/api/v1/sync/changes?since=<ISO8601>` — header `X-Tenant: <company api_key>` |

### The mental model — push is a doorbell, not the data
The broadcast payload is intentionally tiny:

```json
{ "entity": "product", "action": "updated", "id": 4242,
  "company_id": 1, "changed_at": "2026-07-08T19:29:04+05:30" }
```

It only says *what* changed. The POS **never trusts the socket for record data** —
it uses the event only as a signal to call `GET /sync/changes`, which returns the
authoritative list of ids. This keeps the POS correct even if a socket message is
dropped.

### `/sync/changes` response shape
```json
{
  "success": true,
  "synced_at": "2026-07-08T19:29:10+05:30",
  "changes": {
    "customers": { "upserted": [1,2], "deleted": [7] },
    "products":  { "upserted": [4242], "deleted": [] },
    "stocks":    { "upserted": [880], "deleted": [] }
  }
}
```
- `upserted` = created **or** updated (keyed on `updated_at`) → treat as idempotent upsert.
- `deleted` = soft-deleted ids → remove locally.
- Persist `synced_at` and send it back as `?since=` next time.

### The single credential
The POS holds the company's **`api_key`** (already used for other API calls),
sent as the `X-Tenant` header. It authorizes **both** the channel subscription
and the pull endpoint. The Reverb app *secret* never touches the client.

---

## 2. Dependencies

`pubspec.yaml`:
```yaml
dependencies:
  web_socket_channel: ^3.0.0   # raw WS (recommended — full control, no Echo needed)
  http: ^1.2.0                 # pull endpoint
  connectivity_plus: ^6.0.0    # detect reconnects (optional but recommended)
```

> We use the **raw Pusher protocol** over `web_socket_channel` rather than a
> Laravel-Echo Dart port, because the protocol we need is small (connect →
> authorize → subscribe → receive) and Echo Dart ports are unmaintained.

---

## 3. Components to build

```
lib/sync/
  reverb_client.dart      // WS connection, subscribe, auth, reconnect, event stream
  sync_service.dart       // orchestrates: on event OR reconnect -> pullChanges()
  sync_api.dart           // GET /sync/changes
  sync_repository.dart    // apply upserted/deleted ids to local DB (sqflite/Isar/Drift)
  last_sync_store.dart    // persist synced_at (shared_preferences / secure storage)
```

### 3.1 ReverbClient — connect, authorize, subscribe

Pusher handshake sequence the client must implement:

1. Open `ws(s)://{host}:8081/app/{APP_KEY}?protocol=7&client=flutter&version=1.0`
2. Receive `pusher:connection_established` → extract `socket_id` from its `data`.
3. Get an auth token for the **private** channel by POSTing to the backend:
   ```
   POST {BACKEND}/api/broadcasting/auth
   Headers: X-Tenant: <company api_key>, Content-Type: application/json
   Body: { "socket_id": "<socket_id>", "channel_name": "private-company.<id>.sync" }
   → { "auth": "<APP_KEY>:<hmac>" }
   ```
   > The backend ([BroadcastAuthController]) validates the `X-Tenant` key maps to
   > that company id and returns the signature. The POS does **not** compute the
   > HMAC itself — the server does (it holds the secret).
4. Send subscribe frame:
   ```json
   { "event": "pusher:subscribe",
     "data": { "auth": "<auth token>", "channel": "private-company.<id>.sync" } }
   ```
5. Expect `pusher_internal:subscription_succeeded`.
6. Handle incoming frames where `event == "data.changed"` → emit onto a Dart
   `Stream` the SyncService listens to.

Also handle:
- **Ping/pong**: reply to `pusher:ping` with `{"event":"pusher:pong"}`; send a
  ping every ~30s if idle (Reverb activity timeout).
- **Reconnect with backoff**: on socket close/error, reconnect (exponential
  backoff, cap ~30s). After every successful resubscribe, trigger a catch-up pull.

### 3.2 SyncService — orchestration
- On app start: `pullChanges()` once (catch up while offline), then connect WS.
- On `data.changed` event: debounce ~500ms (bursts of edits) then `pullChanges()`.
- On WS reconnect: `pullChanges()` (gap recovery).
- Optionally on `connectivity_plus` regaining network: `pullChanges()`.

### 3.3 SyncApi — pull
```
GET {BACKEND}/api/v1/sync/changes?since=<urlEncoded ISO8601 or empty>
Headers: X-Tenant: <company api_key>
```
- First-ever sync: send empty `since` — note this returns **all** ids (full seed).
  For a large catalog prefer your existing bulk endpoints for the initial load,
  then start `/sync/changes` from that moment's `synced_at`.
- On `401 Invalid tenant`: surface as auth error (bad/rotated api_key).

### 3.4 SyncRepository — apply changes
For each entity in `changes`:
- `upserted`: fetch those records via existing detail/bulk endpoints (the sync
  payload gives ids only), then upsert into local DB.
- `deleted`: delete those ids locally.
- Do it in a transaction; make it idempotent (safe to replay).

### 3.5 LastSyncStore
- Persist `synced_at` from the **successful** pull only (never before applying).
- Key it per company id (multi-store: one POS may switch companies).

---

## 4. Config / env in the Flutter app

```dart
class SyncConfig {
  final String backendBaseUrl;   // https://api.enke...   (no trailing slash)
  final String reverbHost;       // server host
  final int    reverbPort;       // 8081 (as running on the server)
  final bool   useTls;           // true if fronted by TLS proxy (wss) / false for direct ws
  final String reverbAppKey;     // REVERB_APP_KEY (public)
  final String companyApiKey;    // per-tenant, from login/company config
  final int    companyId;
}
```
> Ship `reverbAppKey` as a build constant (it is public). `companyApiKey` comes
> from the authenticated company/session, stored in secure storage.

---

## 5. Edge cases & correctness rules

- **Missed events are fine** — the `since` timestamp on pull guarantees recovery;
  never rely on receiving every socket frame.
- **Clock skew** — always use the server-returned `synced_at` as the next `since`,
  never the device clock.
- **Leading dot** — the event is registered via `broadcastAs()`; match on the raw
  name `data.changed`. (In Echo this is `.data.changed`; in raw protocol it's
  literally `data.changed`.)
- **Auth failure on subscribe** — if `/broadcasting/auth` returns 403, the api_key
  doesn't match the company id; stop retrying and surface a config error.
- **Backgrounding** — mobile OS may kill the socket; treat resume-from-background
  like a reconnect → resubscribe + catch-up pull.
- **Debounce** — bulk edits (e.g. imports) fire many events; debounce before pulling.

---

## 6. Test plan

1. **Unit**: ReverbClient handshake state machine (mock WS frames), SyncService
   debounce, LastSyncStore persistence.
2. **Integration against dev backend**:
   - Start backend Reverb (`php artisan reverb:start`) + `php artisan queue:work`.
   - Edit a product in Filament admin → assert POS receives `data.changed` and
     the product updates locally within ~1s.
   - Kill the socket, edit 3 products, restore network → assert catch-up pull
     applies all 3.
   - Soft-delete a product → assert it disappears locally (`deleted` path).
3. **Manual QA**: airplane-mode toggle, app backgrounding, company switch.

---

## 7. Milestones

- [ ] M1 — SyncApi + SyncRepository + LastSyncStore; manual pull works (no socket).
- [ ] M2 — ReverbClient connect/auth/subscribe; logs incoming `data.changed`.
- [ ] M3 — SyncService wiring (event → debounce → pull → apply); reconnect + backoff.
- [ ] M4 — Startup/background/connectivity catch-up; edge cases.
- [ ] M5 — Tests + QA against dev backend; ship behind a feature flag.

---

## 8. Backend touchpoints (reference, no change needed)

- Broadcast event: `app/Events/PosDataChanged.php`
- Fired by: `app/Observers/PosSyncObserver.php` (Customer/Product/ProductStock)
- Channel auth: `app/Http/Controllers/Api/V1/BroadcastAuthController.php`
- Auth route: `POST /api/broadcasting/auth` (`routes/web.php`)
- Pull: `app/Http/Controllers/Api/V1/SyncController.php` → `GET /api/v1/sync/changes`
  (`routes/api/SyncRoutes.php`)

> Operational note: the backend must run **both** `reverb:start` and a queue
> worker (`queue:work`) for pushes to fire, because `PosDataChanged` is queued
> (`ShouldBroadcast` + `QUEUE_CONNECTION=database`). If pushes are ever delayed,
> the POS still self-heals via the catch-up pull.
