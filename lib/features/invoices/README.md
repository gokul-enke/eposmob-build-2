# Invoice List

This feature owns the Invoice List query, input controller, repository adapter,
list transport, export snapshot, workbook and passive filter/row widgets.
`InvoiceListScreen` remains the existing route entry point and delegates to
`InvoiceListPage`. The shared listing components and existing appearance remain.

The repository adapts `InvoiceProvider` deliberately: visible invoice state and
its latest-request guards are also used by existing actions. Those guards and
public methods remain in the provider. Export reads a separate complete snapshot
and does not publish rows, pagination or filters into visible state.

Invoice details, creation/editing, receipt snapshots, row-action dialogs,
printing and ZATCA sending implementations remain outside this refactor.
Existing API parameters, date/time handling, filters and pagination are retained.

Regression coverage includes controller search/reset/page/export sequences,
selection and disposal, existing invoice responsive layouts and ZATCA setting
transitions, export pagination validation, provider request races and receipt
compatibility. Automated tests use controlled providers/HTTP responses; live
backend and desktop interactions still require manual verification.
