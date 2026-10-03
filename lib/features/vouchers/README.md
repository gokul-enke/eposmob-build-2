# Vouchers

Customer and supplier voucher lists, creation forms and detail dialogs live here.
The migration preserves the existing shared listing UI and HTTP contracts.

## Structure

- `domain/`: unchanged voucher models and pure cached-row filters.
- `data/`: injectable tenant-aware HTTP, repositories, create payloads and PDF I/O.
- `presentation/state/`: the existing providers, owned list inputs and form state.
- `presentation/pages/`: lifecycle, provider wiring and user feedback.
- `presentation/widgets/`: filters, rows, dialogs and form sections receiving data
  and callbacks. Form sections share a view library using Dart `part` files;
  they contain no provider or HTTP lookups.
- `presentation/export/`: Excel column definitions for already loaded rows.
- `presentation/actions/`: customer share and ZATCA actions.
- `presentation/navigation/`: named shell routes and supplier aliases.

## Public surface

Existing callers use `CustomerVoucherProvider` and `SupplierVoucherProvider`
from `presentation/state/`. Their public list, filter, pagination, create and
customer ZATCA methods remain available. Optional repository injection allows
tests to replace HTTP without changing production callers.

Models remain `CustomerVoucher`, `CustomerVoucherModel`, `SupplierVoucher` and
their supporting types, now under `domain/models/`.

The shell mounts `CustomerVoucherListPage`, `SupplierVoucherListPage`,
`CreateCustomerVoucherPage` and `CreateSupplierVoucherPage`. Navigate through
`VoucherNavigation`: customer list/create retain slots 70/71, supplier routes
retain 72/73, and Transactions supplier aliases retain 75/76. Create/back follows
the supplier section the user entered from. No shell slots were reordered.

Print layouts, PDF builders and `ShareHelper` remain shared document services
under `screens/transactions/widgets/`; their model imports were updated. The
unused legacy customer mobile view was removed; the active list already uses
the shared adaptive cards/table layout.

## Preserved behavior

GETs use bearer + tenant headers, active store and the original page size.
Customer date filters fetch from the API; other list filters apply to cached
rows. Supplier loading validates all returned pages and coalesces overlapping
loads. Export flushes pending inputs and exports the same filtered cached rows.
Borrowed export controllers are not disposed by pages.

Create bodies retain their field names and numeric types. Both existing forms
send voucher date as due date. Customer item tax is an absolute amount; supplier
item tax is a percentage. Payment defaults remain CASH, then COD, then the first
available method; the initial status is paid.

ZATCA POSTs retain their form body and 20-second timeout. HTTP/document I/O has
no UI context. Pending form initialization and delayed focus callbacks stop
updating the UI after disposal.

## Verification

Tests mirror the feature under `test/features/vouchers/`; shared transaction
filter tests also cover external callers. Before/after list and form snapshots
at 375 and 1280 pixels are identical. The customer create form's pre-existing
375-pixel overflow is documented in `docs/migrations/vouchers_architecture.md`;
this architecture change does not redesign that form.

Live tenant creation, device printing, sharing and ZATCA delivery require manual
acceptance checks. Unit/widget tests use fixtures and injected HTTP.
