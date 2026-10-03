# features/suppliers

Everything about suppliers: the list, the profile (with its tabs), the one
add/edit form, and the app-wide supplier directory that purchases, stock,
reports and sync read.

Built the same way as `features/customers` (the reference implementation);
see its README for the full set of layer and UI rules.

## Layers

```text
features/suppliers/
├── domain/                    pure Dart
│   ├── models/supplier.dart   Supplier, SupplierKyc, SupplierTransaction, SupplierPurchase…
│   └── supplier_filter.dart   name/email/phone + shared BalanceFilter (core/filters)
├── data/                      HTTP only, no UI state
│   ├── supplier_api.dart      injectable get/post + TenantSession
│   ├── supplier_payloads.dart create/update request bodies
│   └── supplier_repository.dart
└── presentation/
    ├── state/
    │   ├── supplier_provider.dart            app-wide directory + selection (main.dart)
    │   ├── supplier_list_controller.dart     list inputs (debounced), filter toggle, export
    │   ├── supplier_form_controller.dart     add/edit form (+ supplier_form_values.dart)
    │   ├── supplier_transactions_controller.dart / supplier_orders_controller.dart
    │   └── supplier_profile_tab.dart
    ├── navigation/supplier_navigation.dart   the only code that knows sidebar indices
    ├── export/supplier_excel_export.dart
    ├── pages/   suppliers_list_page.dart (ListPageScaffold),
    │            supplier_profile_page.dart (DetailPageScaffold)
    └── widgets/ list/, form/, profile/ (info, transactions, orders), supplier_labels.dart
```

## Public surface for other screens

- `SupplierProvider` — `fetchSuppliers`, `allSuppliers`, `supplierList`,
  `selectedSupplier*`, `fetchSupplierTransactions`, `addSupplier`,
  `updateSupplier`, `clearCachedSuppliers`. Loading the transactions does not
  touch the list's spinner.
- `showAddSupplierDialog(context, {showCreateAnother})` — resolves to
  `{'status': 'success', ...}` or `null`.
- `SupplierNavigation.openList / openProfile`.

Sidebar slots 52 (list), 57 (legacy "details", shows the profile) and 69
(profile) are named on `SideBarController`.

## Export

The list exports every supplier matching the current filters (all pages) to
Excel through `ExportController` + `FileExportService` (`core/export`):
Save As on Windows (the native share UI can terminate the app there), the
share sheet elsewhere. A search still waiting on the debounce is applied in
place first, so the file matches what is typed and the page doesn't jump.

## Tests

```text
test/features/suppliers/
├── domain/   supplier_filter
├── data/     supplier_api (fake HTTP + payloads)
├── presentation/
│   ├── state/   provider, list/form/transactions/orders controllers
│   ├── pages/   list page, profile page (phone + desktop)
│   └── widgets/ form/, profile/
└── support/  supplier fixtures + FakeSupplierRepository
```

Shared fakes (tenant session, JSON responses, app settings, header
actions) live in `test/test_support/`.
