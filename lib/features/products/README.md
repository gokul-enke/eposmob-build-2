# Product List

This change owns only the catalog **listing** at sidebar slot 14. It does not
refactor product creation, editing, details, barcode printing, stock, weighing,
variant editing, billing, synchronization or any inner page/dialog.

## Layers

- `domain/product_list_query.dart`: plain Dart listing inputs.
- `data/product_list_source.dart`: injected catalog reader and existing delete
  callback. Local selection uses the same search helpers and filter rules as
  `LocalProductProvider.listAllProducts` for existing filters. The separately
  authorized Property fix matches populated product properties or variant
  attributes; empty property definitions do not match.
- `presentation/state/product_list_controller.dart`: list-only inputs, debounce,
  Reset, pagination, lifecycle guards and frozen all-pages export snapshots.
- `presentation/pages/product_list_page.dart`: provider wiring and one shared
  `ListPageScaffold`. Reads dependencies once; disposes only owned state.
- `presentation/widgets/list/`: filters, table, cards, labels, actions and copy.
- `presentation/export/product_list_excel.dart`: workbook builder; purchase-price
  permission and item-code setting apply to both the screen and workbook.
- `presentation/navigation/product_list_navigation.dart`: list-only navigation.

## Existing contracts retained

The catalog and `GetProduct` model remain in their existing shared locations.
Moving them would expand the diff into billing, sync and product inner workflows,
which are explicitly excluded. The data adapter uses that existing model but has
no widgets, provider imports, HTTP or storage of its own. This is a list-only
architecture refactor, not a completed migration of the entire Products module.

Filtering retains name/barcode search ranking, category IDs, partial price,
product/stock HSN and case-insensitive item codes. The complete catalog remains
the source, including nonsellable products just as before. List pagination is
local and does not overwrite the shared catalog's billing filters/page.
Refresh continues to clear filters. Add and View open the same existing dialogs;
Delete still calls `LocalProductProvider.deleteProductAPI` with the same ID,
authorization, endpoint, payload and catalog/Hive update behavior.

## Property filter correction

Selecting a property shows products with an assigned value for that property,
not a particular value (e.g. Shirt size means any populated shirt size). Checks
both `product_props.master_value` and `variants.attributes`, once per product;
preserves the order and combines with every other listing filter. Color uses
the catalog code `PRODUCT_COLOR`, with legacy `COLOR` accepted as an alias.
Empty definitions, whitespace-only values and empty collections do not match.
The existing local catalog, provider, models, API and inner pages are unchanged.
Export freezes the same complete filtered result, across all local pages.
Missing property data produces an empty filtered list; Reset restores the full
catalog. This deliberately fixes the old no-op Property filter for this page.

## Public surface

- `ProductListPage` (optional caller-owned `ExportController`)
- `ProductListNavigation.openList()`

Other features continue using the existing catalog/model/provider APIs. This PR
does not change `lib/core/`; header, filters, table/cards, pagination, feedback
and Windows Save As/mobile sharing reuse the shared kit.
Wide tables also use the shared table's visible, draggable horizontal scrollbar;
its controller is owned and disposed by Product List.

## Verification

Baseline: 40 focused existing product/list tests passed before changes.
The final focused run passed 118 tests across this feature, product filters,
catalog/search/stock, local product sync, details helpers, variant selection and
localization integrity. New tests cover filter parity, dropdown dismissal and
Reset, debounce, page bounds, deletion, phone permission changes, frozen export
filters, numeric money and text barcodes with leading zeros. The quick Export
sequence covers a pending no-match edit, empty-result feedback, Reset and a
pending matching edit; no-match exports create no file and throw no exception.
Property regression sequences cover both populated product properties and
variant attributes, ignored empty definitions, other-filter combinations,
page reset, frozen filtered export, and phone/desktop picker interaction.
The Windows mouse-drag sequence checks the shared horizontal scrollbar. A
separate read-only check on a copy of the actual 4,856-product Hive cache found
8 Manufacturer matches, 30 Color matches, 1 Shirt size match and no Shoe size
matches with the new filter. No fresh API request was made for that check.

Full suite before the export-edge fix: 2,327 passed, two skipped, one existing failure in
`standard_pdf_layout_contract_test.dart` (the centered theme does not use the
shared address resolver). Both that test and the renderer are unchanged from
the branch baseline. The additional phone and export-edge sequences passed in
the focused run. Analysis is clean for the feature, tests and sidebar controller; the menu
caller retains its eight existing informational diagnostics.

Before/after renders at 375, 768 and 1280 pixels were captured outside the
repository using fixture products and real fonts. The new page has no overflow;
the legacy table's action cells overflow at 768 pixels. Screenshots are review
artifacts, not evidence of native Windows interaction.
Native Windows dialogs, real API deletion, clipboard and app interaction were
not exercised by these automated tests and remain manual verification items.
