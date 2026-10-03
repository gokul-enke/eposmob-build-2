# Vouchers architecture migration

## Starting point

Branch: `mubashir/expenses-architecture` (retained at the user's request).
Baseline: `2104fe78`, updated from `origin/staging` after Expenses was merged.
The pre-existing local `pubspec.lock` change is unrelated and must be preserved.
The user authorized a local commit after review. Push and PR creation are not authorized.

## Ownership map (step 0)

The target module is `lib/features/vouchers/`, with separate customer and
supplier models, APIs, repositories, providers and page controllers. Shared
voucher presentation helpers may live within this feature; application-wide
printing, document configuration and sharing services remain shared callers.

| Responsibility | Current files |
|---|---|
| Customer model and state | `lib/models/customer_voucher.dart`, `lib/providers/customer_voucher_provider.dart` |
| Supplier model and state | `lib/models/supplier_voucher.dart`, `lib/providers/supplier_voucher_provider.dart` |
| Lists | `lib/screens/transactions/customer_voucher_list.dart`, `supplier_voucher_list.dart` |
| Forms | `lib/screens/transactions/widgets/create_customer_voucher.dart`, `create_supplier_voucher.dart` |
| Detail dialogs | Embedded in both list pages; both use `common_details_dialog.dart` |
| Printing callers | Customer/supplier voucher print pages, standard and thermal printers, template PDF builders |
| Sharing caller | `lib/screens/transactions/widgets/share_helper.dart` (also serves other document types) |
| Registration | `lib/main.dart` |
| Shell callers | `lib/controllers/sidebar_controller.dart`, `lib/widgets/side_menu.dart`, `side_menu_mobile.dart` |
| Existing tests | Customer/supplier voucher list tests, supplier voucher provider tests, shared transaction-filter tests |

`customer_voucher_list_mobile.dart` defines a legacy mobile view but has no
callers in `lib/` or `test/`; the active list uses the shared adaptive layout.
The generic receipt/purchase voucher screens and their models are separate
flows; their names alone do not make them customer/supplier voucher owners.

## Navigation contract

- Customer list/create: 70 / 71.
- Supplier list/create under Suppliers: 72 / 73.
- Supplier list/create under Transactions: 75 / 76 (aliases).
- Preserve alias-aware create/back routing; never insert or reorder shell slots.
- Details are dialogs; print pages are Navigator routes, not additional slots.

## Contracts to preserve

- Both GET lists use bearer and tenant headers, `page=1`, `per_page=1000`, and
  the active store when set. Customer dates are sent to the API; other list
  controls filter cached rows locally.
- Customer loading retains its generation check and last-token/reset behavior.
- Supplier loading coalesces refresh requests, validates every pagination page
  and duplicate ID, and waits for pre-mutation loads before its create refresh.
- Create requests preserve all field names and types, nullable payment method,
  item calculations, and both forms' existing voucher-date-as-due-date behavior.
- Customer ZATCA print/resync use form POST bodies and 20-second timeouts.
- Export includes the filtered cached rows and flushes pending text edits.
- Preserve supplied export-controller ownership, retry state, print/share
  callbacks, and before/after layout at phone and desktop widths.

## Baseline verification

Full checks were completed before source changes:

- `flutter test`: 2,198 passed, two skipped, one pre-existing failure in
  `standard_pdf_layout_contract_test.dart` (centered simplified tax invoice's
  shared address resolver).
- `flutter analyze`: zero errors, 402 warnings and 3,263 infos (3,665 total).
- Logs: `%TEMP%/vouchers-test-before.log` and
  `%TEMP%/vouchers-analyze-before.log`.

Step 1 moved both models with `git mv` and updated every model import, including
print/share/PDF callers. The model source is unchanged from the baseline
(allowing for Git's Windows line-ending conversion).
Touched callers were formatted after dependency resolution. The supplier
provider, both voucher lists and shared transaction-filter tests pass (42 tests;
`%TEMP%/vouchers-model-move-test.log`). This is a verified intermediate step,
not a completed architecture migration. Analysis after this step matches the
baseline exactly: zero errors, 402 warnings and 3,263 infos. `git diff --check`
passes. No commit or push was made.

## Completed migration (steps 0 through 7)

- Step 0: mapped ownership, callers, API contracts and sidebar aliases; captured
  baseline tests/analysis before editing.
- Step 1: moved both models with `git mv`; model fields/parsing are unchanged.
- Step 2: extracted injected GET/POST transport, `TenantSession`, payloads and
  repositories; providers preserve their public methods and loading/filter logic.
- Step 3: extracted pure local filters and owned form/list controllers.
- Step 4: moved the active pages with `git mv`; split filters, rows, details,
  Excel builders and form sections into passive presentation helpers. Removed
  the unreferenced legacy customer mobile view, replaced by active adaptive cards.
- Step 5: centralized named navigation with `isRegistered ? find : put`, including
  desktop/mobile menus and both supplier create/back aliases. Shell slots did not move.
- Step 6: moved existing tests with `git mv`; added injectable API, controller,
  navigation, architecture and create-page tests.
- Step 7: documented the public surface and formatted every touched Dart caller
  after dependency resolution. No shared core files or generated files changed.

## Final verification and review boundaries

- Full suite: **2,216 passed, two skipped, one pre-existing failure** in the same
  `standard_pdf_layout_contract_test.dart` test as baseline. The 18 added tests
  introduce no new suite failures.
- Initial final analysis: zero errors, 399 warnings, 3,235 infos; its one new
  warning was an unused test loop variable, which was removed. The final rerun
  has **zero errors, 398 warnings and 3,235 infos** (3,633 total), with no new
  warning diagnostics compared with baseline. Feature-only analysis has zero
  errors and zero warnings. `git diff --check` passes.
- Before/after PNGs for both lists and both forms at 375 and 1280 pixels have
  identical pixels. They use fixture data and Flutter's widget-test font; they
  verify layout equivalence, not production font rendering or live tenant data.
  Evidence is outside the repository in `%TEMP%/vouchers-*-before-*.png` and
  `%TEMP%/vouchers-*-after-*.png`.
- The customer create form already overflows at 375 pixels (79, 21, 135 and
  31 pixels in this fixture). Before and after are identical. This is an existing
  P2 UI issue for the separate UI PR. Supplier form and desktop forms have no
  overflow in the fixtures.
- Final focused checks: **60 passed**, including 375 x 812 phone and desktop
  page fixtures.
- Supplier list pagination/failure/duplicate-ID checks, customer stale-response
  and date/reset flows, pending export filters, borrowed export ownership,
  initialization after disposal, calculations, payment defaults and alias
  navigation are covered by tests.
- Review: no new P0/P1/P2/P3 issue found in the exercised migration paths.
  Existing customer phone overflow remains above. Existing missing-tenant create
  behavior (throwing before the provider's request catch, leaving its loading
  flag set) is preserved; it is
  not a new contract introduced by the repository extraction.
- Live creation, hardware printing, native share/save dialogs and ZATCA delivery
  remain manual acceptance checks. No live records were created during tests.
- Implementation checks completed before the authorized local commit. No push or PR creation performed. Unrelated `pubspec.lock` is preserved.

## Migration checklist

- [x] Read customers README and architecture guide.
- [x] Update the existing branch from staging; preserve unrelated local work.
- [x] Map source files, external callers, HTTP and navigation contracts.
- [x] Record baseline and before screenshots.
- [x] Move both models with `git mv`; update every model import.
- [x] Move existing tests into the feature test tree.
- [x] Extract injected tenant APIs, payloads and repositories.
- [x] Move providers, preserving their public APIs.
- [x] Split pages into controllers and data/callback-driven leaf widgets.
- [x] Centralize named navigation, including desktop/mobile aliases.
- [x] Add mirrored API/controller/page tests and after screenshots.
- [x] Document public surface; format all touched callers; verify full tests.
- [x] Record final analysis rerun and final whitespace/status check.
- [ ] Senior review and merge of architecture PR (requires later commit/push authorization).
- [ ] Separate UI PR/checklist after architecture review and merge.
