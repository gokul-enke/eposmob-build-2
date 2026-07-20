# Fav Tab — Auto-Generated Favourites in Restaurant Menu

## Current State

The category bar in `lib/screens/billing/restaurant/widgets/menu_panel.dart` renders:

- `idx == 0` → **All** tab (shows all sellable products)
- `idx >= 1` → real categories from `categoryProvider.category`

Products come from `LocalProductProvider` (cached via Hive). The `GetProduct` model has no sales-count field today. There is no existing "Fav" or "popular" endpoint in `lib/resources/app_url.dart`.

---

## Recommended Approach — Backend-Driven

### Why backend?

- "Most used" must reflect actual sales across all sessions/devices, not just the current device.
- The backend already records every order line — it can aggregate `SUM(quantity)` per `product_id`.
- The Fav list refreshes automatically as sales patterns change.

---

## What the Backend Should Return

New endpoint (to be added by the backend team):

```
GET /api/v1/product/top-selling?store_id=X&limit=20
```

Response:
```json
{
  "data": [
    { "product_id": 42, "total_quantity": 148 },
    { "product_id": 7,  "total_quantity": 95 },
    ...
  ]
}
```

- `limit` — how many top items to return (default 20, configurable)
- Optionally add `days=30` to scope by recency (rolling 30-day window)
- Auth: same `X-Tenant` header as all other endpoints

---

## Flutter Changes

### 1. Add URL — `lib/resources/app_url.dart`
```dart
static String get getTopSellingProductsUrl =>
    '$baseURL/api/v1/product/top-selling';
```

### 2. New Provider — `lib/providers/top_selling_provider.dart`
Responsibilities:
- `List<int> topProductIds` — ordered list of product IDs by sales count
- `fetchTopSelling({required int storeId, int limit = 20})` — GET the endpoint, parse, store IDs
- Cache result in `SharedPreferences` (key: `top_selling_ids`) so it works briefly offline
- Expose `bool isLoading`

### 3. Register Provider in `main.dart` / provider tree
Add `ChangeNotifierProvider(create: (_) => TopSellingProvider())` alongside existing providers.

### 4. Update `MenuPanel` — category bar logic

In `menu_panel.dart`, the `ListView.separated` currently uses `itemCount: categories.length + 1` (the +1 is "All"). Change to `categories.length + 2` (+1 for All, +1 for Fav).

```
idx == 0  → All
idx == 1  → Fav  ← new
idx >= 2  → real categories (categories[idx - 2])
```

For `idx == 1` (Fav):
- `categoryId` = special sentinel value, e.g. `-1`
- Products shown = full sellable list filtered to IDs in `topProductIds`, preserving order

### 5. Fav chip styling
Use a star/heart icon + gold accent color to distinguish Fav from regular category chips.

### 6. When to refresh the Fav list
- On `MenuPanel` first load (call `fetchTopSelling` inside `initState`)
- On table selection change (call from `RestaurantPage`)
- Do **not** refetch on every category tap — cache is sufficient within a session

---

## Data Flow

```
Backend DB (order_items table)
        |
        | GET /product/top-selling
        v
TopSellingProvider  ──── topProductIds ────► MenuPanel
                                               │
LocalProductProvider ── sellableProducts ──────┤
                                               │
                              filter by topProductIds
                                               │
                                    ┌──────────┴──────────┐
                               Fav Tab Products      Category Tabs
```

---

## Files to Touch

- `lib/resources/app_url.dart` — Add `getTopSellingProductsUrl`
- `lib/providers/top_selling_provider.dart` — New provider
- `main.dart` — Register provider
- `lib/screens/billing/restaurant/widgets/menu_panel.dart` — Add Fav tab, filter logic, chip UI

---

## No Backend Endpoint Yet? Interim Option

If the backend endpoint is not ready, we can track locally on-device:

- Every time `onItemAdd` is called in `MenuPanel`, increment a counter in `SharedPreferences` keyed by `product_id`
- `TopSellingProvider` reads these local counters and returns top-N IDs

Downside: resets on reinstall, not shared across devices. **Not recommended for production.**
