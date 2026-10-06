# Supplier Transactions Report listing architecture

## Scope and baseline

Only Reports → Supplier Transactions Report listing moves. It is different from
the standalone supplier transactions list and the supplier profile Transactions
tab. The 1,034-line legacy listing becomes a feature page, pure report data/query,
request-local source, controller and real frame/header/filter/table/card widgets.

The report details page and all standard/thermal print files remain untouched.
Shared SupplierProvider, models, SupplierRepository and SupplierApi are unchanged.
The API is already injectable and tenant/store-aware; duplicating it or migrating
shared supplier state would broaden this listing-only scope.

Before migration, 82 focused existing report/supplier API tests passed. Three
populated before/after screenshots (375×812, 1280×900 and 1440×900) are byte-identical.
Captures are outside the repository.

## Guide steps within the listing boundary

0. Mapped directory, grouped report API, selection, caller imports and slots 67/68.
1. Extracted pure supplier summary/query/option/page parsing to reports/domain.
2–3. Reused the public supplier repository/API through a local report source;
     preserved shared provider ownership and HTTP contracts.
4. Moved the listing with git mv, extracted request/input state and real widgets.
5. Named report route constants; ReportNavigation owns listing/details entry points.
   Desktop/mobile listing menus updated. Legacy details back buttons are unchanged.
6. Domain, source/API contract, controller and populated page/workflow tests.
7. Updated Reports README and removed the old listing import/path from lib/test.

## Explicit listing corrections

- Opening the report reads a directory snapshot instead of replacing shared
  supplier list state. Profile selection never becomes the report's filter.
- Filter changes and Reset start at page one, rather than reusing a later page
  belonging to the old filter.
- Date-field keys clear internal displayed dates on Reset without changing the
  shared calendar component.
- Request generations ignore older responses and work after disposal.
- Failed reloads and malformed response envelopes retain the previous page and
  surface an existing translated error toast instead of silently clearing rows.

These corrections are local to the listing. Debit/credit/balance parsing,
ID-based grouping, transaction counts, financial precision, dates sent to the
server, permissions and View's supplier selection contract are retained.

## Verification and limits

Focused command:

```powershell
flutter test --no-pub test/features/reports test/report_filter_screens_test.dart test/features/suppliers/data/supplier_api_test.dart
```

98 focused tests pass. Analyzer reports no errors or new warnings in the migrated
report; moved presentation code retains existing style/deprecation info messages.
Tests cover phone/desktop layouts, supplier/date/Reset/paging sequences, View,
request races, failure/retry and disposal. Shared API contract tests remain.

Full-suite run: 2,307 passed, two skipped, two failures. One was the existing
standard_pdf_layout_contract_test.dart active-store address resolver failure.
The other exposed numeric paginator metadata compatibility; that was corrected,
and the final serial focused run passed all 98 tests, including that regression.
The entire full suite was not repeated after the metadata correction.

No live API, stock/supplier mutation or physical printing was exercised during
architecture verification.

## Shared listing UI follow-up

The reviewer requested the layout in the same PR after the architecture commit.
The listing now uses ListPageScaffold, PageHeader, FilterPanel, shared table
cells, AppListCard/metrics, AppEmptyState and ListPagination. The old custom
frame/header/empty-state widgets are removed. A visible horizontal scrollbar
provides access to all columns at tablet widths. Date filters retain date-only
API bounds through the existing auto-dismiss picker; no time picker is added.
All new labels are present in English, Arabic and Malayalam.

Export uses ExportController/FileExportService and reads all matching supplier
summary pages into a request-local snapshot. It reports page progress, keeps
financial workbook cells numeric and fails on duplicate IDs (including numeric
strings), malformed amounts, changing pagination or incomplete totals. It also
aborts if filters change or the page closes before file delivery. Report-local
scope checks reject changes to the loaded token, tenant, active store or endpoint
before/after export requests and after workbook creation. The confirmed active
store race is covered through the real supplier API with a fake HTTP transport;
page tests also verify cancellation releases busy state without file delivery.
There is no new date-period restriction or shared supplier API/provider change.

The supplier picker keeps a stable widget key. A selection-dependent key caused
dropdown_search 6.0.2 to dispose the picker during its popup's closing animation,
which popped the underlying report route and left the app black. Real popup
search/select/clear/Reset/dismiss tests at 375, 768 and 1280 pixels verify that
only popup routes are popped and the report remains mounted. The customer report
had the same selection-dependent key and now has the same stable-key fix.
Both reports use AppSearchDropdownPopup in the existing shared search-dropdown
UI file, with AppColors for the white surface and blue selection/hover,
AppRadius for the border, and AppTextStyles for search and option text.
The existing form dropdown and other features keep their current behavior.

Before/after UI captures at 375, 768 and 1280 pixels are stored outside the repo
under the system temporary directory supplier-report-previews, using ui-before
and ui-after filename prefixes. The UI follow-up tests include the shared layout
and export-service tests as well as report workflows and localization integrity:
217 tests passed, including scope-change and real-popup regression follow-ups. The captured
before/after layouts were visually inspected at
375, 768 and 1280 pixels. The Customers reference page is unchanged; core/ui gains
the shared popup configuration consumed by the two reports. Real popup tests
also check rendered white surfaces, blue selected options, shared font size,
Escape dismissal, Clear and Reset at phone, tablet and desktop widths.
The Customer Transactions Report's empty From/To fields now reuse the existing
translated Select Date placeholder; selected values, Reset and API time bounds
retain their existing behavior.
Live tenant APIs, native Android/iOS share sheets and physical printing remain
manual verification boundaries.
