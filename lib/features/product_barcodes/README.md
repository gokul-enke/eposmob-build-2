# Product barcode listing

Owns the Product > Product Barcode listing (Print Barcodes), its category/name/barcode filters, expanded-row pagination, print selection and Excel export. This is a list-only architecture and shared-UI change. The detail dialog is extracted intact; its existing responsive detail helper, print confirmation modal, label layouts, printer settings and printer service are unchanged.

## Layers and ownership

- `domain/barcode_list_query.dart`: framework-free filter values and category options.
- `data/barcode_list_source.dart`: adapter over the existing local catalogue and category directory. It delegates filtering to `LocalProductProvider` and uses the same `ProductSearchHelper` when local edits replace filtered entries. No new API endpoints or provider contracts.
- `presentation/models/`: the existing `BarcodeRow` printable adapter and expansion rules. Base rows are always included; active variants and distinct sale-unit barcodes become separate rows. Barcode search narrows those expanded rows. Price resolution, translated print names and stock/date scope are retained.
- `presentation/state/`: page-owned inputs, 300 ms debounce, applied query, 20-row pagination, memoized expansion and stable cross-page selection. Catalogue identity/version changes refresh rows; unrelated notifications keep the page and expansion.
- `presentation/widgets/`: provider-free shared filter/table/card/bulk-action compositions plus the preserved detail dialog.
- `presentation/pages/`: wires providers once, owns the controller, table scrollbar and default export controller, and retains the original print handlers. An injected export controller remains caller-owned.
- `presentation/export/`: freezes primitive values for all matching expanded rows before asynchronous workbook encoding.
- `presentation/navigation/`: the list route at `SideBarController.productBarcodeListScreenIndex` (83).

## Public surface

- `BarcodeListPage`: used by the sidebar shell.
- `BarcodeNavigation.openList()`: sidebar entry point.
- `BarcodeRow.toProductForPrint()`: existing printable base/variant/sale-unit contract, covered by the original print-data tests.

The list uses `ListPageScaffold`, `PageHeader`, `FilterPanel`, `AppDataTable`, `AppListCard`, shared buttons/toasts and `AppPaginationBar`. Mobile header actions fold into More, filters start collapsed, and the wide table has the shared horizontal scrollbar. No `lib/core/ui` changes.

## Selection and printing

Select all selects the current expanded page only. Selection persists across pages and filters; Reset, Clear Selected and successful printing clear it. Print Selected includes the stored selection, including rows outside the current filter. Missing-barcode guards, confirmation arguments, sticker options and success handling retain the existing behavior. Viewing details and cancelling printing do not mutate products or stock.

During provider catalogue synchronization, the list displays its shared loading view and suspends selection, pagination, export and new print requests. Existing print confirmations also check loading before invoking the printer. Rows resume after synchronization completes; an already captured export snapshot remains independent.

## Export

Exports every expanded row matching the applied filters across all pages of the currently loaded local catalogue. It does not mean every server product if the catalogue cache is incomplete, and it is independent of print selection. Pending edits apply before snapshot capture; Reset cancels queued edits. Barcode/SKU values remain text, quantity/price/MRP remain numeric when valid, and unknown values are preserved. Export uses the existing `ExportController` and Excel service: Save As on Windows and the shared delivery behavior elsewhere. Failures use `AppToast`.

## Validation

Run `flutter test --no-pub test/features/product_barcodes test/barcode_filter_test.dart test/barcode_sale_unit_test.dart test/barcode_print_flow_smoke_test.dart test/variant_scoped_stock_test.dart test/product_filter_screens_test.dart`.

Regression coverage includes real provider filters, abandoned category searches, reset/debounce/pagination sequences, live catalogue replacements, cross-page selection, all-page export delivery and frozen values, leading zeros/decimal quantities, disposal/retry, unchanged view/print confirmation, and populated phone/tablet/desktop layouts. Optional rendered previews: set `BARCODE_LIST_PREVIEW=1` and run the `barcode preview capture` test; files go to the system temporary `barcode-list-previews` directory. Native printer delivery and the Windows Save As dialog require manual checking.
