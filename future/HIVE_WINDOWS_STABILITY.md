# Hive on Windows: what was fixed, what was left, what to decide

Date: 2026-09-09
Branch: `hotfix/urgent-fix` (uncommitted at time of writing)
Scope: Hive local storage on the Windows POS client, catalogs of ~30k products.

This document records the analysis, the fixes applied, the verification, and the
open decisions that were deliberately left for later.

---

## 1. Problems found

### 1.1 A failed or slow box open became a dead till with no message (crash)

Startup in `lib/main.dart` tolerated a failed open of `products`, `cart_items`
or `saved_orders`: it recorded a warning and still called `runApp`. But
`LocalProductProvider` grabs those boxes in field initializers with
`Hive.box()`, which throws "Box not found" when the box is not open. The
provider is constructed on the first frame (the realtime sync lifecycle reads
`RealtimeSyncProvider`, whose `create` reads `LocalProductProvider`). The
`provider` package marks a value as initialised even when `create` throws, so
every later read failed too. Result: the window opened, the billing screen was
broken, and the warnings were never shown because the failure screen only
appears for fatal errors.

Realistic triggers on Windows:

- **8 second timeout on a large products box.** Hive 2.2.3 opens a normal box
  by reading the whole file into memory in one call and decoding every frame
  before `openBox` returns. Product JSON has ~126 keys plus nested stock,
  variants and attachments; 30k rows is plausibly 100 to 300 MB on disk. On a
  spinning disk or behind an antivirus scan that exceeds 8 seconds.
- **One poisoned row.** Hive's crash recovery only fixes a truncated or
  CRC-bad tail. A row whose adapter cast fails throws on every open, and the
  old cleanup only deleted the lock file, so the box never opened again.

### 1.2 Every cart action with stock enabled rewrote all 30k products (freeze, data loss)

`_saveProductsToHive` was called from 24 places, including `addProduct`,
`decrementCartItem`, `setCartItemQuantity`, `removeFromCart` and `clearCart`.
It JSON-encoded every product synchronously on the UI thread, truncated the
box to zero, then appended all rows.

- On Windows the Dart UI isolate runs on the platform thread. A multi-second
  synchronous encode stops the Win32 message pump; after ~5 seconds Windows
  labels the window "Not Responding" and cashiers kill it from Task Manager.
- A kill between the truncate and the append left `products.hive` empty or
  partial. Hive recovered silently, but the catalog was gone.
- Rapid taps queued several full rewrites; each one a full-file write.

### 1.3 Startup hang after the window shows

The provider constructor decoded all 30k JSON rows synchronously in the first
post-frame callback, right after the window became visible.

### 1.4 Smaller issues

- `printer_settings.dart` had a dead `clearAllHiveData` that closed the boxes
  the provider holds references to (every cart action would then throw "Box
  has already been closed") and deleted a `Documents/hive` folder that was
  never the Hive location.
- The timeout message blamed a second running copy, which the single-instance
  mutex in `windows/runner/main.cpp` already prevents.
- `_saveConfirmedOrdersToHive` fired `clear()` then `add()` without awaiting
  and outside the persistence queue. A kill between them lost confirmed
  (unsynced) orders.
- Legacy layout: products were stored under auto-increment keys, so a single
  product update was an O(n) scan.

### 1.4b Confirmed from production (Sentry, 2026-09-09 15:24 IST)

A client on the 1.0.62 build (before the single-instance mutex) produced the
exact chain from 1.1 three times in one minute:

```
PathAccessException: lock failed, path = ...\hive_data\products.lock
  (OS Error: The process cannot access the file because another process has
   locked a portion of the file, errno = 33)
PathAccessException: Cannot delete file ... products.lock   (errno = 32)
HiveError: Box not found. Did you forget to call Hive.openBox()?
Bad state: Tried to read a provider that threw during the creation of its value.
```

Two lessons:

- On Windows a lock held by another process does **not** block the open.
  Hive locks in non-blocking mode and the OS throws errno 33 immediately.
  The old "8 second lock timeout" reasoning was wrong; the timeout only ever
  bounded the file read. Lock conflicts need a retry loop, not a timeout.
- A lock conflict must never reach the "delete and recreate" path. The first
  version of this fix would have tried that after three failures. Deleting a
  file another process holds fails on Windows, so nothing would have been
  lost, but the intent was wrong and it is now handled separately (retry for
  6 seconds, then a `StorageLockedException` naming the box and telling the
  user to end cloudpos.exe).

### 1.5 Things that were already fine

- Type ids 0 to 11 are unique; every adapter is registered; generated adapters
  default missing booleans and nums, so adding fields is backward compatible.
- Persistence is serialised through one ordered queue.
- Delta sync already falls back to a full sync when the local baseline is empty.
- Translations are JSON assets loaded into memory via GetX; they do not touch
  Hive.
- The `categories` box is deleted on every launch by design (offline launch has
  no sellable categories until the API answers).

---

## 2. Fixes applied

### 2.1 `lib/main.dart`

- `products`, `cart_items`, `saved_orders`, `confirmed_orders` are now required
  startup steps. A failure goes to the existing failure screen.
- Box open timeout scales with file size: 8 s base + 1 s per 10 MB, capped at
  90 s. The overall startup budget is 300 s.
- A products box that is genuinely unreadable after three attempts (not a
  timeout) is deleted and recreated, reported to Sentry and listed in the
  startup warnings. Carts and orders are never deleted.
- Timeout message now states the file size and likely causes.
- Lock-file cleanup uses the same directory Hive was initialised with.

### 2.2 `lib/providers/local_product_provider.dart`

- Rows keyed by product id. `put(productId, row)` replaces the O(n) key scan.
- Dirty tracking: stock mutations (`_updateStockQuantityInternal`,
  `_adjustVariantQuantity`) mark the product dirty; cart operations call
  `_flushDirtyProducts()` which writes only those rows. The full rewrite
  remains only for wholesale replacements (full sync, realtime apply with no
  changed-id set, key migration, reset).
- Full rewrites upsert then prune. The box is never truncated, so a kill
  mid-write cannot leave it empty. Encoding is chunked (300 rows) with yields
  to the event loop.
- Hydration decodes in chunks of 300 with yields and swaps the finished list
  atomically. The first chunk runs synchronously in the constructor, so small
  boxes behave exactly as before. Exposed as `Future<void> hydrated` and
  `bool isHydrated`.
- One-time migration: legacy auto-increment rows are detected, duplicates
  collapse to the latest row, unreadable rows are skipped, and the box is
  rewritten with product-id keys.
- Catalog epoch: `initializeProducts`, `applyRealtimeCatalog`,
  `fetchProductsFromAPI`, `resetProducts`, `clearAllLocalData` bump an epoch;
  a hydration that started earlier discards its result. Products added in
  place during hydration survive the swap.
- `fetchProductsFromAPI`, `applyRealtimeCatalog`, `mergeRealtimeCatalog` await
  hydration before deciding full-versus-delta.
- Delta sync persists only the fetched and deleted rows. Realtime merges pass
  the changed id set and persist only those plus reservation-touched rows.
- Confirmed orders keyed by order id, written through the persistence queue,
  with stale keys pruned afterwards. The box binding is synchronous when the
  box is already open so an order confirmed right after construction is not
  dropped by a late reload.

### 2.3 Other

- Removed `clearAllHiveData` and its now-unused imports from
  `lib/screens/print/printer_settings.dart`.
- `lib/features/realtime_sync/data/realtime_sync_repository.dart` awaits
  hydration before checking the product baseline.

---

## 3. Verification

| Check | Result |
|---|---|
| New `test/local_product_provider_hive_persistence_test.dart`, 11 tests | all pass |
| Every test file that uses `LocalProductProvider` (39 files) | 380 pass |
| Full `flutter test` | 941 pass, 1 fail (pre-existing, see below) |
| `flutter analyze` on touched files | 0 errors, 2 pre-existing warnings |
| `flutter analyze lib` | 0 errors |
| `flutter build windows --release` | built `cloudpos.exe` |

The single failure is `test/receipt_configuration_workspace_test.dart`. It
expects the text "Receipt Setup & Live Preview", which no longer exists in the
app. The test was last touched 2026-08-20 and the widget on 2026-09-02, so it
was broken before this work and is unrelated to Hive.

Pre-existing analyzer warnings in the provider: `_updateProductStockInList` is
unused, and a redundant null check in `minimumSalePriceForProduct`.

Not verified: a live run on a real 30k-product client machine. The behaviour
under that load is reasoned from Hive internals and covered by the 1000-row
chunked-hydration tests, not measured on hardware.

---

## 4. Decisions left open

### 4.1 Memory footprint at 30k products

**Status: unchanged.** Three copies live at once: the raw file bytes during
open (transient), Hive's in-memory cache of every row with its JSON string
(persistent, normal `Box` behaviour), and the decoded `GetProduct` lists
(persistent). Expect several hundred MB to a gigabyte of working set. Not a
crash on a 64-bit machine with enough RAM, but on 2 to 4 GB terminals it pages
and makes freezes more likely.

Options:

| Option | Effect | Cost |
|---|---|---|
| Keep as is | No change | Memory pressure on small terminals |
| `LazyBox` for products | Drops Hive's in-memory copy | `get` per key is a file read; 30k reads at startup. Needs the keys-only hydration path redesigned, probably with a separate index |
| Store less per row | Keep only fields billing needs (id, name, barcode, price, stock quantities); fetch the full product on demand | Model split and API work; product details screen needs a fetch |
| Move the catalog to SQLite (`sqflite`/`drift`) | Query by barcode/name without loading everything; memory bounded | Largest change; migration of existing client data |

Recommendation if the memory becomes a real complaint: "store less per row"
first, since it also shrinks the file and the open time.

### 4.2 Hive folder under Roaming AppData

**Status: unchanged.** `getApplicationSupportDirectory()` on Windows resolves
to `%APPDATA%\com.enke\pos_machine\epos\hive_data` (Roaming). On domain-joined
machines with roaming profiles a 200 MB hive folder syncs at logon and logoff.

Moving to `%LOCALAPPDATA%` needs a one-time migration (rename the folder on
first launch if the new location is empty and the old one exists; fall back to
the old path if the rename fails). Not a crash fix, so it was not bundled into
a hotfix. Decide based on whether any client actually uses roaming profiles.

### 4.3 Hidden window during a long box open

The Windows runner shows the window on Flutter's first frame. With the new
size-aware timeout a very large box can legitimately keep the window hidden
for tens of seconds, which looks like "the app did not open". Options: a native
splash from the runner before Flutter starts, or opening the products box after
`runApp` and hydrating the provider once it is ready (the provider would need
to accept a box future instead of grabbing the box in a field initializer).

### 4.4 Full rewrite cost on a 30k box

A full sync or a full realtime apply now does one `putAll` of all rows followed
by Hive's automatic compaction, so roughly two full-file writes instead of one.
That is the price of never truncating. On the first launch after this update
every existing client also pays this once for the key migration. If it proves
too slow on real hardware, consider a custom `compactionStrategy` on the
products box in `main.dart` that defers compaction until idle.

### 4.5 `resetProducts` still truncates

`resetProducts` (offline data clear, settings) intentionally clears the box.
That is the one remaining truncation path and is user-initiated.

### 4.6 Pre-existing warnings and the broken receipt test

Both are outside this change. The receipt test needs its expected text updated
to match the current workspace widget.

---

## 5. Rollout notes

- The single-instance mutex shipped in 1.0.65+75. The client whose Sentry
  events are quoted in 1.4b was on 1.0.62. Any client below 1.0.65 will keep
  producing lock conflicts from repeated double-clicks until updated; this
  hotfix should ship on top of 1.0.65 or later.

- First launch after the update rewrites the products box once (key migration
  plus compaction). Expect a longer first start on large catalogs.
- If a client reports the failure screen with a "did not open within Ns" line,
  the file size is printed; that tells you whether it is a slow disk or a lock.
- If a client's products box is reset by the recovery path, Sentry receives
  `Could not read "products" storage (reset)` and the app performs a full sync
  on next login because the baseline is empty.
