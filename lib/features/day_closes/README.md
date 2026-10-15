# Daily Sales Close list

This feature owns the user list (sidebar index 78) and admin records list
(index 84), their filters, pagination, and Excel exports. The Sales feature's `DailySalesCloseListPage`
delegates to `DayCloseListPage` and supplies `OpenShiftModal`, `DayCloseModal`
and the `SalesNavigation` detail route. `AdminDailySalesCloseListPage` supplies
the existing detail route with return index 84. Day Close calculations,
submission, Open Shift, and View details remain in the Sales feature.

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
shift.

## Admin records list

- The admin repository reuses the existing daily-close parser. It always sends
  current `store_id[]`, omits `user_id[]` for all executives, and includes it
  only for a selected executive. A date supplies equal start/end bounds.
  Executive choices use the existing scalar `store_id` contract.
- Requests own frozen authentication/tenant/store/actor scopes. The controller
  owns list, query, pagination, and independent executive lookup error/retry.
  Failed later-page requests retain same-query rows with a stale warning and
  disable Export. Scope changes invalidate rows, choices, and selection.
- The executive popup uses shared styling with separate transient search.
  IDs determine selection even when names repeat. A refreshed lookup cannot
  hide a selected executive while that API filter remains applied.
- Reset clears both filters and reloads page 1, even when already unfiltered.
  Refresh retains filters and recovers the last available page after shrink.
- Export independently fetches all pages. It rejects repeated close IDs,
  scope mismatch, inconsistent counts, and incomplete/nonfinite amounts.
  Repeated executives across different closes are expected. Workbook close
  IDs and executive IDs are separate text columns; phones retain leading
  zeroes, amounts are numeric, and legacy missing business dates stay blank.
  Query/scope/reload changes cancel obsolete export delivery.
- Shared header, filter panel, table/cards, content-fitting frame, and
  horizontal scrollbar preserve existing admin columns, including executive
  ID and closing period. No operator shift actions are added to this list.
