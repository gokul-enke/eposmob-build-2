# Product Sales Report listing migration

Scope: the Product Sales Report list (sidebar slot 40), its local filter and
request state, HTTP operation, existing all-pages Excel export and shared list UI.
No product forms, billing, sale details, day close, purchase returns or report
inner pages are migrated.

Initial base: local origin/staging snapshot 8a28a7b1. Work is on
mubashir/product-sales-report. The branch was created directly from staging,
without inheriting another unmerged feature branch. Git delivery follows the
user-authorized sequence: commit, integrate current staging, verify, then push.
The requested architecture and UI work are developed together locally; the
architecture and UI responsibilities below identify them for review. This is
the user's requested scope override of the guide's separate-PR sequence.

## Architecture steps 0 through 7

0. Mapped the legacy screen, model, Product Sales portion of ReportsProvider,
   sidebar slot, desktop/mobile menus, permission helper and existing tests.
   Baseline: 16 report tests passed. Full suite: 2,297 passed, two skipped,
   one existing standard_pdf_layout_contract_test address-resolver failure.
   Analyzer baseline: 3,641 existing diagnostics. Logs are in the system temp
   directory with the product-sales- prefix.
1. Moved the pure model with git mv to reports/domain/models. Parsing, field
   names and financial values are unchanged. Every old import is updated;
   there is no compatibility export at the legacy path.
2. Extracted ProductSalesApi with injected HTTP and TenantSession. URL, query
   names, tenant/bearer headers, 15-second timeout and failure behavior remain
   the same. In particular, no store_id query parameter was added.
3. ReportsProvider is a shared adapter for several unmigrated reports, so it
   stays in place. Only its Product Sales method delegates to the extracted
   API. Its getter, method parameters and updateState notifications remain
   unchanged; report/export calls keep updateState false.
4. Moved/renamed the screen to ProductSalesReportPage. Its local controller
   owns filters, directory snapshots, the serialized latest-request queue,
   failed-load flags, page target and export snapshot. Leaf widgets receive
   values/callbacks and do not read providers or make HTTP requests.
5. Named slot 40 productSalesReportScreenIndex; desktop/mobile navigation
   uses ReportNavigation. Permissions, menu order and route slot are unchanged.
6. Moved existing model/URI/translation tests and replaced old layout assertions
   with shared-layout assertions. Added API, controller, snapshot, query,
   navigation, real menu/date/Reset and workbook tests under test/features/reports.
7. Updated the feature README and this handoff. Production files are below
   400 lines; no part files, numbered sections, old-path wrappers or unrelated
   module migrations were introduced. The requested shared metric styling
   follow-up is identified separately below.

## UI checklist and behavior

- ListPageScaffold supplies layout, responsive table/cards, loading/empty state,
  pull-to-refresh and pagination. PageHeader actions are Filters, Export, Refresh.
- FilterPanel keeps category, product, From, To and customer filters. Category
  changes clear an incompatible product. All/Reset restore unfiltered page one.
  Search menu typing filters choices; selection triggers one server reload.
  Reset recreates the picker input even when no option was selected, clearing
  uncommitted search text as well as filter values.
- Date filters remain date-only and use the existing auto-dismiss calendar.
  Both have a translated Select Date placeholder. From after To never reaches
  the API, clears results and disables Export, matching the legacy behavior.
- API-provided revenue/quantity totals remain separate from the current page.
  Display formatting stays two decimal places for money, integers or three
  decimal places for quantities. Excel retains full numeric values.
- Filter options load independently, preserving successful option groups when
  another group fails. The report remains usable and offers an options-only Retry.
  Retry is disabled until the current directory batch finishes, and the controller
  also rejects overlapping directory loads. A settled failure remains retryable.
- Report failures clear results as before; Retry uses the intended page,
  including page one after a failed filter change.
- Shared ExportController/FileExportService supplies Windows Save As and the
  mobile share sheet. Every matching page is fetched with the existing 250-row
  export page size. No date-period limit is introduced. The workbook schema,
  file prefix and sheet name are unchanged.
- Export safety checks reject changing/incomplete pagination and nonfinite
  amounts; filter, disposal and token/tenant/store/endpoint changes cancel before
  delivery. These guards are identified improvements to the legacy export loop,
  not changes to report calculations or endpoint parameters.
- Before/after fixture captures at 375, 768 and 1280 pixels are included in
  product_sales_report_images beside this handoff. They are deterministic widget
  renders with fixture data, not live tenant or physical-device screenshots.

Live tenant data, Windows Save As, native mobile sharing and physical devices
remain manual verification boundaries. The pre-existing PDF failure is outside
this listing scope.

## Verification results

- Broad focused run: 191 passed (report features, shared UI/export, permissions,
  localization integrity and existing report filters). Final page/query/navigation
  run: 11 passed, including real search-menu selection, calendar dismissal and Reset.
- Full suite: 2,318 passed, two skipped, three failures. The existing PDF address
  resolver failure matches the baseline. The two existing legacy Save As overwrite
  tests use fixed 100 ms waits; both passed in a separate rerun (all five tests in
  export_windows_save_test.dart passed). No shared export implementation changed.
- An earlier full run was interrupted after its test asset directory disappeared.
  The completed rerun regenerated those assets and had no missing-shader or
  mobile stock-label failures.
- Full analyzer: 3,641 diagnostics, identical to baseline after ignoring line
  shifts. Changed report feature code and tests have no analyzer diagnostics.
- Formatting and git diff --check pass. Before/after fixture renders were inspected
  at 375, 768 and 1280 pixels. The shared scaffold caps and scrolls taller filter
  panels so the results remain visible at narrower widths.
- Original pubspec.lock bytes were preserved during implementation. Inner pages
  are unchanged by this refactor. Shared metric styling affects the appearance
  of their existing AppMetric usages without changing their logic.

## Review follow-up: Reset, directory Retry and totals icons

Both reported P2 cases were reproduced before editing. Regression coverage checks
typed searches in all three unselected pickers, repeated Reset, a partial directory
failure while another directory is pending, the disabled Retry button and a
successful Retry after that batch settles. The table remains usable during a
directory-only outage.

Follow-up validation: 197 focused tests passed across reports, shared UI/export,
permissions, localization and existing report filters. Both original bug
reproductions pass after the fix. The 11 page tests also pass with rendered fixture
captures; the 375, 768 and 1280-pixel images were inspected. Formatting and diff
checks pass. Focused analysis of the reports feature, its tests and the changed
core metric files reports no issues. Native device and live endpoint boundaries
remain as stated above.

The senior's requested styling changes the shared AppMetric default to 24-pixel
primary blue icons, using AppSizes.metricIcon. Product Sales totals and every other
AppMetric caller without explicit styling inherit this appearance. Optional
iconSize/iconColor properties still permit an explicit override, verified in a
shared-widget test. No alternative metric component was introduced. The shared
styling is a separate commit for review and is explicitly identified in the
combined delivery requested by the user, alongside the listing migration.

Shared-default follow-up: 166 tests passed across core UI, report pages, expense,
customer, supplier and voucher listings. Focused analysis of the shared metric
files and test reports no issues. This supersedes the earlier Product Sales-only
icon styling; all default AppMetric usages now inherit 24-pixel blue icons.
