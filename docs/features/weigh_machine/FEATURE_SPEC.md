# Weigh Machine Feature

This document describes the weigh machine download page.

## Scope

Included:

- Writing every product with an SKU to `PLU.csv` for the weigh machine
- Saving `PLU.csv` to a chosen folder, manually or automatically
- Syncing the catalog before saving
- Exporting product details to Excel

The CSV columns are defined in `PluCsv` and are unchanged by UI work.

## Data

Products come from the local catalog (`LocalProductProvider`). No extra API
call is made unless the user syncs.

Per tenant and store, `PluExportService` stores in shared preferences:

- Ticked product IDs (for Excel only)
- Save folder
- Auto-update on or off

## Weighted products

A product is **weighted** (a weigh-machine item) when it has a non-blank SKU in
the active store (`PluCsv.skuOf`). The catalog API usually leaves the product's
own `sku` empty and sets it on each store's stock rows (`stock[].sku`), so the
product-level SKU wins, then the latest stock row of the active store. Stock
rows of other stores are ignored. The back office sets an SKU only on
products sold through the scale. The `weight_info.is_weighted` flag is not
used; the catalog does not send it.

- `PLU.csv` always contains **every** weighted product. Ticks do not affect
  it. Download, Sync & download and the automatic update all write the full
  list, and `PluExportService.export` drops anything without an SKU.
- A product that gets an SKU in the back office reaches `PLU.csv` on the next
  sync; one that loses its SKU drops out. Whether the scale then deletes it
  depends on the scale's own import setting.
- Scale labels are still matched at billing by **barcode**, not SKU.


## Automatic writes

With **Keep file up to date** on, `PluExportService` (bound once at startup in
`main.dart`) rewrites `PLU.csv` whenever the product catalog changes: app
start, the product download after store selection, realtime updates, manual
sync or refresh, and Sync & download. It waits until loading ends, then for
2 seconds of quiet, and writes only when the content differs from the file
on disk. The toggle and folder are per tenant and store.

## Session changes

`PLU.csv` is a copy of the product catalog, so it is removed wherever the
catalog is cleared (`PluExportService.discardFile`):

| Action | PLU.csv |
|---|---|
| Logout | Kept. The same store usually logs back in. |
| Login to a different store (or switching store in the app) | Removed in `StoreSessionProvider.bootstrapStore`, before the old store ID is replaced |
| Reset API key (tenant change) | Removed in `SessionResetService._reset`, before saved settings are wiped |
| Clear local storage | Removed the same way |

The file is rebuilt from the API after the next login and sync when “Keep file
up to date” is on; otherwise press Download. Only `PLU.csv` and
`PLU.csv.tmp` are removed, never other files in the folder. A write already in
progress finishes first, then the file is deleted. Automatic writes then pause
until the old catalog is cleared and a fresh one finishes loading, so the old
store's products are never written back. Reset API key and Clear local
storage also wipe the toggle and folder, like other settings.

## Ticks (Excel)

Ticks choose products for Excel's **Only ticked products** option. Any product
can be ticked, with or without an SKU. Ticks never change `PLU.csv`.

- Tapping a row or its checkbox toggles the product.
- View chips: **All**, **Selected**, **Weighted**. Each shows its count. The
  page opens on **Weighted**; Reset returns to it.
- Chip counts follow the current search and category.
- Search matches product name or barcode, case-insensitive.
- Search, Category and Reset use the same 48px shadow box as
  `CustomDropDownWithSearch`, so the filter row lines up.
- Category is a searchable dropdown (`CustomDropDownWithSearch`). Type to
  filter the list; × returns to all categories.
- Desktop: the table header checkbox selects or deselects all shown products.
  It shows a dash when only some are selected.
- Mobile: **Select shown** / **Deselect shown** does the same.
- **Reset** (next to Category; full width on mobile) clears search and
  category and returns to the Weighted view. It is disabled when there is
  nothing to reset.
- Deselecting shown products or clearing the selection shows a message with
  **Undo** for 5 seconds.

## Machine file panel

- Status banner:
  - Green, “N products ready”: the number of products with an SKU.
  - Amber, “No products with an SKU”, asking the back office to add SKUs.
- Save folder with a **Change** button. The default is `Documents/epos/PLU`
  (created automatically), next to the app's other files in `Documents/epos`.
  After choosing another folder, **Use default folder** switches back. On
  Android and iOS a hint reminds the user to pick a folder the machine can
  read.
- **Keep file up to date** switch turns automatic rewriting on or off. See
  “Automatic writes”.
- **Download PLU.csv** is disabled when no product has an SKU.
- **Sync & download** fetches the catalog first, then saves.
- After a save, “Last saved at HH:MM · N products” is shown. Hover shows the
  full path.
- Only the running action shows a spinner; other actions are disabled.

## Layout

- Content width 1000px or more: product table on the left, machine file panel
  (340px) on the right. The table scrolls; the panel stays in view.
- Narrower: one scrolling column with the machine file panel, filters and
  product cards. A sticky bottom bar shows “N products in PLU.csv”,
  **Untick N** (when anything is ticked) and **Download**.

The table shows:

- Checkbox
- Product name, with a green **Weighted** badge when it has an SKU
- SKU (`—` when blank)
- Category
- Barcode
- Unit
- Price

Cards show the same information.

## Display rules

- Prices use two decimal places; missing prices show `—`.
- Counts use locale grouping (for example, `4,855`).
- Selected rows and cards use a light blue background.

## States

- Empty catalog: “No products yet” with **Sync catalog**.
- Selected view with nothing selected: “Nothing selected yet” with
  **Show all products**.
- Weighted view with no SKU products: “No weighted products”, asking the back
  office to add SKUs, with **Show all products**.
- No search or category match: “No matching products” with **Reset filters**.
- Messages use `showScaffold` (green) and `showScaffoldError` (red) from
  `lib/newcomponents/custom_dialog_box.dart`, like the rest of the app.

## Excel export

The header **Export Excel** button opens a dialog to choose columns and whether
to export only ticked products. Only **Product Name** is ticked by default;
**Select all** ticks every column and **Name only** goes back to the default.
Without "Only ticked products", it exports every product matching the
current search and category.
