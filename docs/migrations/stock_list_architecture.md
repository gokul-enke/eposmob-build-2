# Stock listing architecture

## Scope

Listing only, per the revised team instruction. `stock.dart` moves to
`lib/features/stock/presentation/pages/stock_list_page.dart` with `git mv`.
The list keeps its existing visual design; a later UI PR follows review/merge.

The shared stock provider, HTTP endpoints, models, pending-stock workflows,
realtime merge logic, stock detail page and add/edit/adjust/move/withdraw
implementations are unchanged. The embedded read-only details dialog keeps
its existing layout and fields.

## Guide steps within this scope

0. Map list dependencies and establish the baseline: 11 existing tests pass.
1–3. Shared model/API/provider migration is deferred because those files also
     serve inner pages and stock mutation workflows. No replacement API or
     duplicate provider is introduced in this listing-only PR.
4. Extract owned list input/loading/options state and real presentation widgets.
   Providers are cached by the page; controller operations take callbacks.
5. Name listing/add slots 15/18 and use StockNavigation for list actions.
   The side menu uses the list constant. Inner-page routing stays unchanged.
6. Retain existing tests and add list controller, workflow/layout and row-action
   tests under test/features/stock.
7. Document public boundaries in the feature README and remove the old list file.

## Verification

- 22 focused tests pass: list initialization/filter/reset/disposal, variant model
  and pending-stock validation, row callbacks, paging, realtime updates and
  existing responsive filter tests.
- Whole suite: 2,292 passed, two skipped, one existing failure in
  standard_pdf_layout_contract_test.dart (central active-store address resolver).
  That test and its PDF implementation are unchanged by this migration.
- Whole-project analyzer: no errors; no warnings in the new Stock feature.
- Populated before/after screenshots are byte-identical at 375×812,
  1280×900 and 1440×900. Screenshots stay outside the repository.
- Formatting and git diff --check pass.
- No inner stock file, shared stock provider/model or unrelated lockfile content
  was changed by this task. No live stock write was submitted.

## Lifecycle corrections

The owned controller disposes the status and dropdown-search inputs along with
all other list inputs. Leaving during initialization prevents further page-owned
work and notifications. Missing authentication no longer leaves the list's local
loading flag enabled. These are list lifecycle fixes, not stock business-rule or
request-contract changes.
