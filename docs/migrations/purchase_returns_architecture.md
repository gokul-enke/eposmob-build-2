# Purchase Returns architecture migration

This follows steps 0–7 of `docs/FEATURE_ARCHITECTURE_GUIDE.md`. It changes code
ownership and separates state/data/UI; the listing UI redesign is a later PR.

## Step 0 — ownership and baseline

Original files: `models/purchase_return_model.dart`,
`helpers/purchase_return_pricing.dart`, `screens/purchase_return/` (list, create,
detail dialog), and the four return methods/state fields on `PurchaseProvider`.
External callers are the sidebar screen list, both side menus and the shared
purchase filter-screen tests. No billing/report/sync callers of the four return
methods were found. Sidebar slots remain 99 (list) and 100 (create).

Baseline full suite: 2,216 passed, 2 skipped, one existing failure in
`standard_pdf_layout_contract_test.dart`,
“all six standard themes resolve the active-store address centrally”.
Baseline analysis: zero errors, 398 warnings, 3,235 infos (3,633 total).

## Steps 1–3 — domain, requests and observable compatibility

Models and pricing were moved with `git mv`; old import paths have no reexports.
The domain remains independent of Flutter, translations, HTTP and preferences.
The API receives HTTP get/post functions and `TenantSession`. Repository calls
return snapshots. Existing endpoint, headers, pagination/date/supplier fields,
timeout, validation-error extraction and payment payload were retained.

Return state is now in `PurchaseReturnProvider`. The still-shared
`PurchaseProvider` delegates only its return functionality, forwarding existing
notifications and exposing compatible getters/setters and method signatures.
It retains ownership of every other Purchase API. Its original constructor
initialization remains intact and disposal releases the owned return provider.

The create flow's voucher-selector read is a request-local lookup of the existing
purchase-order endpoint, with the same active-store default. This prevents the
return selector from replacing rows/pagination in the Purchases list.

## Steps 4–5 — controllers, UI and routes

The three screens were moved with `git mv` and renamed to `…Page`.
List, create and detail state lives in disposable `ChangeNotifier` controllers
with injected callbacks. Pages use `ListenableBuilder`; views receive their
state/currency/callbacks and do not look up auth/providers or issue HTTP.
UI helper methods are split into feature-local part files below 400 lines.

Named sidebar constants and `PurchaseReturnNavigation` replace return route
literals in desktop/mobile navigation. Existing positions and drawer closing
remain intact. Late completions do not update disposed controllers; older
requests cannot overwrite a newer selection/filter/page. Back navigation
invalidates the in-flight selected-voucher items request.

## Steps 6–7 — verification and cleanup

- Existing pricing/model tests moved under `test/features/purchase_returns/`.
- API contract and legacy adapter tests include failure and missing-tenant cases.
- Controller tests include reset/retry, stale responses, back/dispose, pricing,
  paid amounts and duplicate submissions.
- Real pages tested at 375×812 and 1440×900, including the create sequence.
- Eight before/after widget PNG pairs matched exactly at 375px and 1280px: list,
  voucher-selector, populated return-form and detail-dialog fixtures. Captures use Flutter
  test fonts; they do not verify installed production fonts.
- The populated 375px form reproduces the original payment-row overflows (48px
  and 86px). These are recorded as pre-existing UI issues for the later UI PR;
  the overflow captures establish equivalence, not mobile-layout correctness.
- Shared purchase filter-panel tests remain in place.
- Old return screen/model/helper imports removed; no `lib/core` changes.
- Scratch screenshot harness, PNGs and verification logs kept outside the repo.

No live API submission or Windows application build was performed. The supplied
`pubspec.lock` modification is unrelated and is excluded from this migration.
The prior Vouchers commit is untouched; this migration is a separate change.

Final verification: 42 focused checks passed. The full suite has 2,249 passed,
2 skipped and the same single pre-existing PDF address-contract failure as the
baseline. No new test failures were introduced by this migration.
Final analysis: zero errors, 398 warnings and 3,245 infos (3,643 total);
no new warnings compared with the baseline. `git diff --check` passes.
