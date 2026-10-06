# Stock Report listing architecture and shared UI

Scope: Reports → Stock Report, sidebar slot 98, on `mubashir/stock-report`.
The user authorized architecture and shared layout together locally, plus a
shared Export action. No inner pages or stock mutation workflows are included.
The base is staging commit `8a28a7b1`.

## Architecture guide steps 0–7

0. Read the Customers reference README and both architecture/layout guides.
   Map the current Stock Report model, HTTP method, eight filters, permissions,
   summaries, pagination and desktop/mobile menu paths. Baseline whole suite:
   2,297 passed, two skipped, one existing PDF address-resolver failure.
1. Move the stock report model with `git mv` into report domain models. Extract
   report-local pagination to remove its dependency on the global model folder;
   read optional total metadata for the new export.
2. Extract only the stock HTTP read into injectable `StockReportApi`. Keep
   endpoint, request names, date precision, headers, timeout and active store.
3. Retain the shared `ReportsProvider` and its existing public stock method.
   Add a request-local snapshot method; leave other reports untouched.
4. Move the listing page with `git mv`, extract its controller and real filter,
   date, table/card, barcode and total widgets. Providers are cached once and
   leaves receive values/callbacks. No raw API or provider access in leaves.
5. Name slot 98 and route desktop/mobile menu access through ReportNavigation.
6. Add API, query, controller, snapshot, workbook, native filter/date, phone/
   desktop and navigation tests. Retain the existing model and report-filter
   coverage at the new model path.
7. Update all imports, remove old paths, format callers and document the public
   surface. Validate the diff, focused analysis, broader tests and renders.

## Behavior boundaries

Store/category/local-product choices reuse the existing shell directories.
Product filtering remains by name. Category changes do not clear the independent
product selection. Reset and input changes start at page one; refresh retries
the intended page even if the previous request failed. Empty success and failed
or malformed responses remain distinguishable. Failed reloads retain rows with
a visible error and disable export/pagination until recovery.

The listing and export share the selected query. All-pages export keeps its own
rows and validates pagination without a date/row limit. Costs are omitted from
table, phone cards, total strip and workbook without the existing purchase-order
permission. Session/filter/permission changes cancel export before delivery.

Native menus avoid replacing the page's route and use shared white surface
tokens. Small directories retain AppSearchDropdownField. The large product
directory uses a local MenuAnchor/ListView.builder adapter with shared field
styling, keeping all choices searchable while building only visible rows.
Reset also clears typed searches that never selected an option. Dates
retain 2000–2101 bounds and date-only API values, and now have placeholders and
clear actions. Inverted ranges do not call the API; malformed expiry values
render a placeholder. These are listing validation/lifecycle improvements.

## UI checklist

- Shared ListPageScaffold, PageHeader, FilterPanel, searchable dropdowns,
  table cells, cards, AppMetric, pagination, AppToast and ExportController.
- Phone filters collapse; the capped shared filter area scrolls on short views.
- Table scroll starts at the first column, with the shared horizontal scrollbar.
- Controlled reset, date clear, retry, empty/error/loading and active filters.
- English, Arabic and Malayalam strings; no new colours or changes in `lib/core/`.
- The shared 24px blue metric change belongs to Product Sales PR #309, which
  is not on this base. Stock inherits that shared change when it is merged;
  this branch does not copy or mix that unrelated commit.

## Validation boundaries

Mocked HTTP, widget input sequences and workbook contents are verified locally.
Native Windows Save As/mobile sharing and the authenticated live Stock API need
manual checking. Before/after phone and desktop renders use the same fixture;
temporary capture code and images stay outside the final tracked change.

## Final local checks

- Whole suite after migration: 2,336 passed, two skipped, only the baseline
  `standard_pdf_layout_contract_test.dart` active-store address resolver failure.
- Report regression directory: 108 tests passed; the separate temporary
  before/after capture run passed four renders with real fonts at 375×812 and
  1280×900. Images are in the system temporary `stock-report-review-captures`
  directory, outside the source tree.
- Changed-file analysis: no errors or new warnings; the existing unused
  purchase-navigation import/deprecation hints in the mobile menu remain.
  New Stock production files and tests have no analyzer diagnostics.
- `git diff --check` and formatting pass.
- The initial review missed a catalog-scale dropdown regression subsequently
  reproduced by the user on Windows. The eager picker mounted 5,000 buttons and
  took 10.19 seconds to open in the widget harness. The replacement mounted
  seven rows and took 0.37 seconds with the same directory. These measurements
  describe the test harness, not a native Windows frame-time guarantee.
- Added 10,000-product widget coverage for repeated opening, search at the end
  of the directory, scrolling, keyboard selection, Escape/outside/Tab dismissal,
  reset and disposal, plus no report requests on opening/searching. Native
  Windows catalog interaction still needs the user's manual retest.
- Dropdown fix validation: all 121 report regression tests passed. The final
  five picker tests also pass at normal, narrow and 300px-high viewports with
  10,000 products. Focused analysis has no diagnostics; formatting and diff
  checks pass. No shared core files, API/filter contracts or inner pages changed
  for this fix.
- Follow-up review fixes: export now rejects duplicate product IDs in flat,
  single-page and overlapping-page responses, even when counts match or total
  metadata is absent. A failed snapshot never builds a workbook or replaces
  visible rows. The first keyboard Up/Down on a closed product menu scrolls
  its highlight after layout; callbacks check menu visibility and disposal.
  All 53 focused Stock contract, picker and page tests pass, including the two
  reproduced review cases and deferred-scroll close/disposal sequences.
