# Offline-First Kitchen (Restaurant / Store) — Plan

**App:** `eposmob` (Flutter) · **Backend:** `enkepos` (Laravel)
**Goal:** Send to Kitchen, running table orders and KOTs keep working with no internet, and never create duplicates when the internet comes back.

---

## 1. The idea in one picture

```
 Cashier taps "Send to Kitchen"
          │
          ▼
 ┌──────────────────────┐     ┌────────────┐
 │ 1. Save to Hive      │ ──▶ │ 2. Print   │   (works offline)
 │    (order + outbox)  │     │    KOT     │
 └──────────────────────┘     └────────────┘
          │
          ▼  (when online, retry until done)
 ┌──────────────────────┐
 │ 3. POST to server    │  with a UUID → server applies it ONCE
 └──────────────────────┘
```

**Rule:** the phone saves first, prints second, syncs last.
Every request carries a UUID, so sending it twice is harmless.

---

## 2. What is wrong today

| # | Problem | Where | What happens |
|---|---|---|---|
| 1 | Send to Kitchen has no UUID | `restaurant_page.dart` `_sendOrderToKitchen`, `_printOrderWithLoading` | Timeout → cashier taps again → **2 orders, 2 KOTs** |
| 2 | Send to Kitchen hidden offline | `order_panel_current_cart.dart` | Kitchen gets nothing while offline |
| 3 | Fake tables when API fails | `table_provider.dart` `_mockTables()` | Staff see T1…T12 that don't exist |
| 4 | Running orders not cached | `order_panel.dart` → `listSavedOrders` | Offline = empty list |
| 5 | Drafts saved by `clear()` + `addAll()` | `local_product_provider.dart` | Crash in between = all drafts lost |
| 6 | `add-to-cart` adds qty | `CartController@add_to_cart` | Retry → **qty doubled** |
| 7 | Shared cart per customer | `CartService.php` `Cart::firstOrCreate` | Two walk-in tables can merge into one order |
| 8 | KOT cancel queue is JSON, no lock | `OrderHelper::appendCancelKOTEvent` | Two voids at once → one lost |
| 9 | Token number only from server | `CartHelper::generateTokenNumber` | Offline device has no token to print |
| 10 | `clearCartAPI` sends `customer_id: "1"` | `cart_provider.dart` | Clears the wrong cart |
| 11 | App POSTs `order/executive/order-details` | `order_panel.dart` | Server only has GET → always fails |
| 12 | `list-saved-orders` ignores `store_id` | `OrderController@listConfirmedOrders` | Other store's orders can show |
| 13 | Kitchen screen never auto-refreshes | `kitchen_master.dart` | Kitchen must tap refresh |

**Good news:** the backend already dedupes `add-to-order` **if** `client_sale_id` is sent
(`OrderController@add_to_order` + `identityPayloadHash` + unique index from
`2026_09_26_000001_add_offline_receipt_identity_to_orders_table.php`).
Settle uses it. Kitchen send just doesn't.

---

## 3. Phase 0 — Quick wins (app only, no backend change)

### 3.1 Send a UUID with Send to Kitchen

**Before**
```dart
final response = await cartProvider.addToOrderAPI(
  items: items, cartIds: 0, status: "new", tableId: _activeTableId, ...
);
```

**After**
```dart
// Created ONCE per order and saved with the draft — reuse it on every retry.
final clientOrderId = draft.clientOrderId ??= const Uuid().v7();

final response = await cartProvider.addToOrderAPI(
  items: items, cartIds: 0, status: "new", tableId: _activeTableId,
  clientSaleId: clientOrderId,   // ← new
  ...
);
```

**Server behaviour (already exists):**

| Request | Result |
|---|---|
| 1st send, `client_sale_id = A` | New order `ORD-000120` |
| Retry, same `A`, same body | Same `ORD-000120`, `idempotent_replay: true` |
| Same `A`, different body | `409 client_sale_id_conflict` |

### 3.2 Treat timeout as "pending", not "failed"

```dart
switch (result.state) {
  case synced:    clearCart(); break;
  case rejected:  showError(); break;            // 400/422 — keep cart
  case unknown:   markPending(clientOrderId);    // timeout — keep, retry same UUID
}
```

### 3.3 Other small fixes

| Fix | How |
|---|---|
| Cache tables | Save `TABLE_LIST` to a Hive box `tables`; delete `_mockTables()` |
| Safe draft save | `box.putAll(byId)` + delete removed keys (same as `confirmed_orders`) |
| `clearCartAPI` | Send the real `cart_id`, not `customer_id: "1"` |
| Order details | Call `GET order/executive/order-details/{order_number}` |
| Auto-retry | Now safe with UUIDs → retry with backoff (5s, 15s, 60s, 5m) |

---

## 4. Phase 1 — Local kitchen model (app)

New Hive box: **`kitchen_orders`**. One entry per open table/order.

```dart
class KitchenOrder {
  String clientOrderId;      // UUIDv7 — made on device
  int?   serverOrderId;      // filled after sync
  String? orderNumber;       // ORD-000120 after sync
  String localToken;         // "C1-0042" — printed on KOT offline
  String? tableId, tableName, deliveryMethodId;
  int?   customerId;
  SyncState syncState;       // local | pending | synced | needsReview
  List<KitchenLine> lines;
  List<KotTicket> kots;
}

class KitchenLine {
  String clientLineId;       // UUID — never changes
  int productId; num qty; num price; String? comment;
  int? kotSeq;               // which KOT sent it (null = not sent yet)
  num voidedQty;
}

class KotTicket {
  String kotId;              // UUID
  int seq;                   // 1, 2, 3 … per order
  List<String> lineIds;
  DateTime printedAt;
}
```

**Example — table T4 over time**

| Step | Action | Lines | KOTs |
|---|---|---|---|
| 1 | Add 2 Biryani, 1 Coke | L1 Biryani ×2, L2 Coke ×1 (`kotSeq` null) | — |
| 2 | Send to Kitchen | L1, L2 → `kotSeq: 1` | KOT #1 printed |
| 3 | Add 1 Naan | L3 Naan ×1 | — |
| 4 | Send to Kitchen | L3 → `kotSeq: 2` | KOT #2 (only Naan) |
| 5 | Void 1 Biryani | L1 `voidedQty: 1` | Cancel KOT printed |

Also:
- On load, copy server running orders (`list-saved-orders`) into `kitchen_orders` → visible offline.
- One working order **per table** (no more single global cart + auto-draft on table switch).

---

## 5. Phase 2 — Outbox of operations (app)

Don't sync the whole order. Sync **small operations**, each with its own `op_id`.

```json
{ "op_id": "0192…a1", "type": "create_order", "client_order_id": "0192…77",
  "table_id": "T4", "lines": [{ "client_line_id": "L1", "product_id": 55, "qty": 2, "price": 250 }] }

{ "op_id": "0192…a2", "type": "add_lines",   "client_order_id": "0192…77",
  "lines": [{ "client_line_id": "L3", "product_id": 61, "qty": 1, "price": 40 }] }

{ "op_id": "0192…a3", "type": "void_line",   "client_order_id": "0192…77",
  "client_line_id": "L1", "qty": 1 }

{ "op_id": "0192…a4", "type": "settle",      "client_order_id": "0192…77",
  "client_sale_id": "0192…77", "paid_methods": [...] }
```

**Rules**
- Ops for the **same order** go in order (a2 waits for a1).
- Different orders sync in parallel.
- Reuse `LocalSaleSyncService` → use the unused `LocalSaleOperation.kitchenOrder`.
- Show a small badge on each order: ☁️ synced · ⏳ pending · ⚠️ review.

**Offline Send to Kitchen flow**
```dart
await kitchenRepo.saveOp(op);         // 1. Hive
await KotPrintPage.autoPrint(...);    // 2. local printer (already works offline)
outbox.kick();                        // 3. sync when online
```

---

## 6. Phase 3 — Backend changes (`enkepos`)

### 6.1 Idempotency table (for every cart/order change)

```php
// migration: pos_operations
Schema::create('pos_operations', function (Blueprint $t) {
    $t->id();
    $t->unsignedBigInteger('company_id');
    $t->uuid('op_id');
    $t->string('type');
    $t->json('response');
    $t->timestamps();
    $t->unique(['company_id', 'op_id']);
});
```

```php
// Same op_id twice → return the saved response, do nothing again.
if ($done = PosOperation::where('company_id', $cid)->where('op_id', $opId)->first()) {
    return response()->json($done->response);
}
```

### 6.2 One endpoint for kitchen ops

```
POST /api/v1/kitchen/orders/{client_order_id}/ops
Body: { "ops": [ {op}, {op}, ... ] }        // applied in order, one transaction
```

The device never waits for a server id — everything is keyed by `client_order_id`.

### 6.3 Lines keyed by UUID (upsert, not increment)

```php
// migration: cart_items.client_line_id (uuid, nullable, unique per cart)

CartItem::updateOrCreate(
    ['cart_id' => $cart->id, 'client_line_id' => $line['client_line_id']],
    ['product_id' => $line['product_id'], 'quantity' => $line['qty'], 'price' => $line['price']]
);
```
Retry = same row, same qty. No doubling.

### 6.4 One cart per order (fixes table merge)

```php
// Before: Cart::firstOrCreate(['customer_id'=>..,'store_id'=>..,'status'=>'N', ...])
// After:
$cart = Cart::firstOrCreate(['client_order_id' => $clientOrderId], [...]);
```

### 6.5 Lock the order on every change

```php
DB::transaction(function () use ($clientOrderId) {
    $order = Order::where('client_sale_id', $clientOrderId)->lockForUpdate()->firstOrFail();
    // apply ops...
});
```

### 6.6 KOT events as a table (not JSON)

```php
// migration: kot_events
// id, company_id, order_id, kot_id (uuid), cart_item_id, type (send|cancel),
// qty, printed_at, created_at
```
Replaces `KOT_CANCEL_QUEUE` in `OrderHelper::appendCancelKOTEvent`. `acknowledge-kot-print` sets `printed_at`.

### 6.7 Token number from device

| | Today | New |
|---|---|---|
| Who makes it | Server (`CartHelper::generateTokenNumber`) | Device: `{counter}-{seq}` e.g. `C1-0042` |
| Offline | ❌ none | ✅ printed on KOT |
| Stored as | `ORDER_TOKEN_NUMBER` prop | `client_token_number` (+ server token if still wanted) |

> **Decision needed:** which number does the kitchen call out? Recommended: the device token.

### 6.8 Small backend fixes

| Fix | Where |
|---|---|
| Filter by `store_id` | `OrderController@listConfirmedOrders` |
| Saudi: `BROADCAST_CONNECTION=reverb` | Saudi `.env` |
| Check `phone:null` path doesn't reuse customer 1's cart | `OrderHelper::getOrCreateCustomer` |

---

## 7. Phase 4 — Live updates & multiple devices

**Live refresh (online)**
```dart
// realtime_sync_repository.dart — on 'orders' change:
_sales.refreshOrdersForRealtime(ids);
restaurantOrders.refresh(ids);   // ← new: order panel
kitchenScreen.refresh(ids);      // ← new: kitchen_master.dart
```
Plus a 20s polling fallback when the socket is down.

**Two devices, both offline — what happens?**

| Case | Result |
|---|---|
| Both add items to T4 | ✅ Merged — lines have different UUIDs |
| Both void the same line | ⚠️ Second one rejected → `needsReview` |
| Both open a *new* order on T4 | ⚠️ Two orders on T4 → shown on sync, staff merges |

> When the internet is down, **the KOT printer is the only way orders reach the kitchen.**
> Make sure KOT printers are on the local network (LAN/Wi-Fi), not cloud printers.

---

## 8. Order of work

| Phase | Who | Fixes | Size |
|---|---|---|---|
| 0 | App | Duplicate KOTs, fake tables, lost drafts | Small |
| 1 | App | Running orders visible offline | Medium |
| 2 | App | Send to Kitchen offline | Medium |
| 3 | Backend | Retry-safe edits, table merge, lost voids, token | Medium |
| 4 | Both | Live kitchen screen, multi-device | Small–Medium |

**Do Phase 0 first** — it stops duplicate kitchen orders with zero backend work.

---

## 9. Key files

**App (`eposmob`)**
- `lib/screens/billing/restaurant/restaurant_page.dart` — send / print / add item
- `lib/screens/billing/restaurant/widgets/order_panel.dart` — running orders, offline confirm, KOT print
- `lib/providers/restaurant/table_provider.dart` — tables
- `lib/providers/local_product_provider.dart` — cart, drafts, Hive
- `lib/providers/cart_provider.dart` — HTTP calls
- `lib/services/local_sale_sync_service.dart` — outbox
- `lib/services/local_first_sale_coordinator.dart` — save → print → sync
- `lib/screens/print/print_kot.dart` — KOT print (already offline-safe)
- `lib/screens/billing/kitchen_master.dart` — kitchen screen
- `lib/features/realtime_sync/` — Reverb socket

**Backend (`enkepos`)**
- `routes/api/OrderRoutes.php`, `routes/api/CartRoutes.php`, `routes/api/SyncRoutes.php`
- `app/Http/Controllers/Api/V1/OrderController.php` — `add_to_order`, `updateOrder`, `listConfirmedOrders`, `acknowledgeKotPrint`
- `app/Http/Controllers/Api/V1/CartController.php` — `add_to_cart`, `manage_cart`
- `app/Services/CartService.php` — `Cart::firstOrCreate`
- `app/Helper/CartHelper.php` — order number, token number
- `app/Helper/OrderHelper.php` — order props, KOT cancel queue
