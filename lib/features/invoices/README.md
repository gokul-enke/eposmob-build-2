# Invoice List

This feature owns the Invoice List query, input controller, repository adapter,
list transport, export snapshot, workbook and passive filter/row widgets.
`InvoiceListScreen` remains the existing route entry point and delegates to
`InvoiceListPage`. The shared listing components and existing appearance remain.

The repository adapts `InvoiceProvider` deliberately: visible invoice state and
its latest-request guards are also used by existing actions. Those guards and
public methods remain in the provider. Export reads a separate complete snapshot
and does not publish rows, pagination or filters into visible state.

The active Create Invoice dialog now lives in `presentation/widgets`, with
form orchestration and lifecycle in `presentation/state`, parsed items and
summary calculations in `domain`, and a create-provider adapter in `data`.
The controller is a part of the dialog library so existing private form fields
and callbacks can remain unchanged while rendering is separated from them.
`screens/transactions/create_invoice_modal.dart` exports the existing public
entry point and widget types for compatibility.

The active Invoice Details action and passive dialog also live in this feature.
Its repository reads request-local details with the existing endpoint, tenant,
token and optional store parameters. A failed or mismatched response cannot
reuse a previously opened invoice. Legacy standalone invoice screens are
unchanged; sharing, receipt snapshots, other row-action dialogs,
printing and ZATCA sending remain outside this refactor.
Existing API parameters, date/time handling, filters and pagination are retained.

Regression coverage includes controller search/reset/page/export sequences,
selection and disposal, existing invoice responsive layouts and ZATCA setting
transitions, export pagination validation, provider request races and receipt
compatibility. Automated tests use controlled providers/HTTP responses; live
backend and desktop interactions still require manual verification.

Inner-dialog regression tests cover form validation, saved item totals, retry
after failure, duplicate submission, success closing with `true` (the list's
existing refresh signal), delayed lookup disposal, payment/discount payload
forwarding, decimal details, authentication/store scope, and overlapping or
failed details reads. Source comparisons retain the original calculations,
submission parameters, lookup scope, and remaining dialog controls.

Create uses the complete request-local customer snapshot rather than the shared
customer listing's current page. This restores access to named customers beyond
that page without changing the shared listing's filters or rows. Customers with
null names still use the existing Unknown label.

The requested create-form layout correction gives Status and Payment Method
enough room for selected text and their clear/arrow buttons. Controls wrap and
the summary moves below when the dialog is narrower. Summary labels and amounts
can wrap, and the narrow-screen title no longer overflows. Readability tests use
the actual Poppins font across six viewport widths, including resizing with
selections retained, cancel/reopen, and failed or empty lookups.

Three review passes cover layout, complete form/lookup sequences, and baseline
calculation/transport/details compatibility. Two pre-existing P2 risks remain
because this task preserves business logic: clearing a payment method or failing
to load its directory still submits the fixed fallback ID 206, which may not be
valid for the tenant; reducing saved item amounts after a flat discount can make
the payable amount negative, and submission does not validate that case. Backend
acceptance of these invalid cases has not been tested. No new regression was
identified in the exercised cases; passing tests are not an exhaustive guarantee.

Manual verification should include create, cancel, discounts, and reopening
the created invoice from the refreshed list. Automated tests perform no live
invoice creation or native printing/ZATCA requests.
