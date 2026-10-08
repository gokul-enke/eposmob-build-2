# Daily Sales Close list

This feature owns only the user list (sidebar index 78), its date filter,
pagination, and Excel export. The compatibility screen delegates to the shared
list UI. Admin lists, Open Shift, Day Close calculations/submission, and View
details remain in their existing implementations.

- The repository freezes authentication, tenant, store, and user for each
  request. Listing keeps `store_id[]`, `user_id[]`, and identical `start_date`
  and `end_date` bounds. Pending status uses scalar store/user parameters.
- List and pending-shift requests have independent loading, errors, retry,
  and stale-response guards. A pending-status failure preserves valid rows and
  export, and disables shift actions until retry succeeds. Existing draft
  information and success callbacks are passed to the original dialogs.
- Date changes and Reset return to page 1. Refresh keeps the current date and
  recovers the last available page if records shrink. Export never updates a
  shared provider or changes the visible page.
- Export fetches all pages, rejects inconsistent pagination, duplicate close
  IDs, foreign scope, invalid quantities, and missing/non-finite amounts.
  Authentication, scope, filter, or reload changes cancel an obsolete export.
  Old records with no business date keep that cell blank; recorded closing
  periods and opening/closing dates are included without inventing a date.
- Desktop uses the shared horizontal scrollbar and content-fitting table;
  mobile uses shared cards and collapsible filters. Open Shift and Day Close
  use shared labeled buttons in the header. View uses the shared blue action.
  Windows export uses the shared Save As service; other platforms use sharing.

Regression tests cover the wire contract, empty/error distinction, full-page
snapshots, legacy rows, filter/reset/retry, asynchronous races and disposal,
pending status, callbacks, workbook cell types, and localized layouts. Live
business mutations must be checked manually; tests do not open or close a real
shift. The unchanged modal retains its pre-existing analyzer warnings.
