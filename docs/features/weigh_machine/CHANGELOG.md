# Weigh Machine Changelog

## 2026-09-23

- Redesigned the page to match the Customers page style.
- Desktop: product table beside a machine file panel that stays in view.
- Mobile: product cards and a sticky bar with the selected count and Download.
- Moved save folder and auto-update out of the settings dialog into the panel.
- Added All / Selected / Weighted views with counts, a header select-all
  checkbox, a clear-search button and specific empty states.
- Added a ready / not-ready status banner and a last-saved line.
- Added confirmation before selecting over 200 products and Undo for
  deselecting.
- Prices now show two decimal places.
- Added a Reset filters button like the Customers page.
- Search, Category and Reset now share the `lib/newcomponents` look: 48px
  white box, soft shadow, 7px corners, primary outline on focus.
- Default save folder is now `Documents/epos/PLU` instead of Downloads, with a
  **Use default folder** link after choosing another folder. Excel exports
  from this page go to the same folder.
- Weighted now means “has an SKU”. PLU.csv always holds every SKU product and
  ignores ticks; ticks are for Excel's “Only ticked products” and work on any
  product. The page opens on the Weighted view and shows an SKU column.
- Removed the 200-product confirmation; ticking only affects Excel now.
- PLU.csv is removed on store switch, Reset API key and Clear local storage
  (kept on logout), so another store's or tenant's items never stay where
  the scale imports.
- SKU is read from the active store's stock rows when the product has none
  of its own (the API puts it there). Excel's SKU column uses the same rule.
- Excel export now ticks only Product Name by default, with a Select all link.
- Category is now the shared searchable dropdown, which also fixes Reset not
  clearing the selected category.
- Messages now use `custom_dialog_box.dart` overlays instead of snackbars.
  `showScaffold` gained an optional action button (used for Undo).
- Added widget tests for both layouts.
