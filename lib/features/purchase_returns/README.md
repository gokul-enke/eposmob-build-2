# Purchase Returns

Architecture-only migration of the purchase-return list, create flow and detail
dialog. Their existing PurchaseOrders responsive UI is preserved. The separate
UI migration onto the shared listing kit follows review/merge of this work.

## Ownership

- `domain/models/`: return responses and editable return line payload.
- `domain/purchase_return_pricing.dart`: existing voucher-discount allocation,
  currency rounding and quantity formatting (pure Dart).
- `domain/purchase_return_filter.dart`: nullable query values.
- `data/purchase_return_api.dart`: injected HTTP and `TenantSession`; existing
  URLs, tenant headers, query fields, create payload and error messages.
- `data/purchase_return_repository.dart`: request-local access to the API.
- `presentation/state/`: legacy observable provider and separate list, create
  and detail controllers. Controllers receive fetch/submit functions.
- `presentation/pages/`: provider/auth wiring, lifecycle, toasts and navigation.
- `presentation/widgets/`: unchanged list/form/detail sections, supplied with
  state, currency and callbacks. Part files share private UI helpers without
  looking up providers or accessing storage/HTTP.
- `presentation/navigation/`: named sidebar routes, preserving slots 99/100.

## Public surface

- `PurchaseReturnListPage`, `CreatePurchaseReturnPage` and the dialog-shaped
  `PurchaseReturnDetailsPage(returnData: ...)`.
- `PurchaseReturnNavigation.openList()` / `.openCreate()`.
- Domain response classes and `PurchaseReturnPricing`.
- `PurchaseReturnApi` / `PurchaseReturnRepository` injectable for testing.
- `PurchaseReturnProvider`, accessible through
  `PurchaseProvider.purchaseReturnProvider`.

`PurchaseProvider` remains in its existing location because it owns Purchases as
well. Its return methods, mutable fields/getters/setters and notifications remain
compatible through a feature-owned adapter. Moving the entire provider belongs
to the subsequent Purchases migration, not this module.

Pages use request-local `fetchPage` / `fetchItems` and never publish their active
rows into the legacy shared provider. The return form's purchase-voucher lookup
also returns a snapshot; it preserves active-store scoping and the existing
selector's empty/error fallback without changing the Purchases list.
The supplier catalogue and payment-method cache remain shared dependencies.
Pure return models reference the existing pure purchase-order model for supplier
and voucher types; that model still belongs to Purchases.

## Behavior and checks

The create flow preserves fractional quantities, one editable row per purchase
item, two-decimal currency rounding, manual paid amounts, optional payment
fields, `has_payment` boolean, return-date format and success navigation.
The legacy provider still clears return rows and notifies on request errors;
missing tenant credentials fail before changing shared state. Detail failures
still show the supplied summary. Page controllers ignore obsolete or disposed
request completions; submission captures its payload and blocks duplicate taps.

Run:

```sh
flutter test test/features/purchase_returns test/purchase_filter_screens_test.dart
flutter analyze
flutter test
```

Tests cover injected requests, payload/errors, provider compatibility and state
isolation, filters/reset/retry, stale requests/disposal, item edits, payment
validation, duplicate submission, details fallback, phone/desktop rendering and
the create sequence. Existing model/pricing tests were moved with Git history.
No live server requests or Windows binary build are part of these tests.

The populated form has a pre-existing 375px payment-row overflow. Before/after
captures reproduce the same 48px and 86px overflows; this architecture change
retains them for the subsequent UI migration rather than mixing a layout fix.
