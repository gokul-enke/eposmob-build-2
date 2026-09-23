# Weigh Machine Feature

This document describes the weigh machine download page.

## Scope

Included:

- Choosing which products go into `PLU.csv`
- Saving `PLU.csv` to a chosen folder, manually or automatically
- Syncing the catalog before saving
- Exporting product details to Excel

The CSV columns are defined in `PluCsv` and are unchanged by UI work.

## Data

Products come from the local catalog (`LocalProductProvider`). No extra API
call is made unless the user syncs.

Per tenant and store, `PluExportService` stores in shared preferences:

- Selected product IDs
- Save folder
- Auto-update on or off

Until the user changes the selection, products flagged as weighted are
selected by default.

## Selection

- Tapping a row or its checkbox toggles the product.
- View chips: **All**, **Selected**, **Weighted**. Each shows its count.
- Chip counts follow the current search and category.
- Search matches product name or barcode, case-insensitive.
- Search, Category and Reset use the same 48px shadow box as
  `CustomDropDownWithSearch`, so the filter row lines up.
- Category is a searchable dropdown (`CustomDropDownWithSearch`). Type to
  filter the list; × returns to all categories.
- Desktop: the table header checkbox selects or deselects all shown products.
  It shows a dash when only some are selected.
- Mobile: **Select shown** / **Deselect shown** does the same.
- Selecting more than 200 products at once asks for confirmation.
- **Reset** (next to Category; full width on mobile) clears search, category
  and view. It is disabled when nothing is filtered.
- Deselecting shown products or clearing the selection shows a message with
  **Undo** for 5 seconds.

## Machine file panel

- Status banner:
  - Green, “N products ready” when at least one product is selected.
  - Amber, “No products selected” with guidance otherwise.
- Save folder with a **Change** button. On Android and iOS a hint reminds the
  user to pick a folder the machine can read.
- **Keep file up to date** switch turns automatic rewriting on or off.
- **Download PLU.csv** is disabled when nothing is selected.
- **Sync & download** fetches the catalog first, then saves.
- After a save, “Last saved at HH:MM · N products” is shown. Hover shows the
  full path.
- Only the running action shows a spinner; other actions are disabled.

## Layout

- Content width 1000px or more: product table on the left, machine file panel
  (340px) on the right. The table scrolls; the panel stays in view.
- Narrower: one scrolling column with the machine file panel, filters and
  product cards. A sticky bottom bar shows the selected count, **Clear
  selection** and **Download**.

The table shows:

- Checkbox
- Product name, with a green **Weighted** badge when flagged
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
- Weighted view with no flagged products: “No weighted products” with
  **Show all products**.
- No search or category match: “No matching products” with **Reset filters**.
- Messages use `showScaffold` (green) and `showScaffoldError` (red) from
  `lib/newcomponents/custom_dialog_box.dart`, like the rest of the app.

## Excel export

The header **Export Excel** button opens a dialog to choose columns and whether
to export only selected items. Only **Product Name** is ticked by default;
**Select all** ticks every column and **Name only** goes back to the default.
Without "Only selected machine items", it exports every product matching the
current search and category.
