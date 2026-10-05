# Moving a Module to the Feature Architecture — Work Guide

## Goal

Every module (purchases, sales, products, stock, expenses, …) ends up in its
own folder under `lib/features/<module>/`, split the same way as
`lib/features/customers/` — the **reference implementation**. Read its
`README.md` before you start; `features/suppliers` and `features/reports`
are two more finished examples.

This guide is only about **where code lives and how the layers talk to each
other**. How list pages look is in
[`LISTING_PAGE_LAYOUT_GUIDE.md`](LISTING_PAGE_LAYOUT_GUIDE.md).

> **One module, two PRs — never both in one PR.**
>
> 1. **Architecture PR** (this guide): move and split the code. The app
>    looks and behaves exactly as before.
> 2. **UI PR** (the layout guide): move its list pages onto the shared kit.
>
> A move-only PR is easy to review ("nothing changed, it only moved"), and
> if something breaks you know which kind of change caused it.

---

## 1. The target layout

```text
lib/features/<module>/
├── README.md                  what the module owns + its public surface
├── domain/                    pure Dart: no Flutter, no HTTP, no storage
│   ├── models/                data classes + fromJson/toJson
│   └── <module>_filter.dart   filter / sort / display rules
├── data/                      talks to the outside world, no UI state
│   ├── <module>_api.dart      HTTP only (injectable get/post + TenantSession)
│   ├── <module>_cache.dart    Hive copy (only if the module works offline)
│   ├── <module>_payloads.dart request bodies
│   └── <module>_repository.dart  API + cache behind one class
└── presentation/
    ├── state/                 ChangeNotifiers, no widgets
    │   ├── <module>_provider.dart         app-wide state (registered in main.dart)
    │   └── <module>_list_controller.dart  one controller per page/tab/form
    ├── navigation/<module>_navigation.dart  the only code that knows sidebar indices
    ├── export/                Excel builders (if the module exports)
    ├── pages/                 screens the sidebar shows (ListPageScaffold / DetailPageScaffold)
    └── widgets/               leaf widgets, grouped by page: list/, form/, profile/ …

test/features/<module>/        the same folders, one test file per lib file
└── support/                   fakes and JSON fixtures for this module
```

Not every module needs every folder: a module with no offline mode has no
cache, a report has no form. Don't create empty folders.

### What goes where — quick decisions

| You have… | It goes in |
|---|---|
| A model class with `fromJson` | `domain/models/` |
| "Is this row overdue?", filtering, sorting, label rules with no `.tr` | `domain/` |
| `http.get(...)`, URL building, headers, status-code handling | `data/<module>_api.dart` |
| Turning a form into a request body | `data/<module>_payloads.dart` |
| Hive boxes | `data/<module>_cache.dart` |
| State several screens share (the list, the selected item) | `presentation/state/<module>_provider.dart` |
| State of one page / tab / form (text fields, debounce, paging, filters shown) | `presentation/state/<page>_controller.dart` |
| `SideBarController` index changes | `presentation/navigation/` |
| Text through `.tr` | `presentation/widgets/<module>_labels.dart` or the widget itself |
| Anything two modules need (a button, a date field, a debouncer) | `lib/core/` — never import one feature from another's internals |

---

## 2. Dependency rules

These are what keep the structure from rotting. Reviewers check them first.

- `domain/` imports only `domain/` and `dart:` — no Flutter, no `.tr`, no
  packages that do I/O.
- `data/` imports `domain/`, `core/`, `resources/app_url.dart` and packages
  (`http`, `hive`) — **never** widgets, providers or `BuildContext`.
- `presentation/state/` imports `data/`, `domain/`, `core/`. No widgets.
- **Pages** read providers and own their controllers. **Leaf widgets** get
  data and callbacks through their constructor — they never call
  `Provider.of` / `context.read`, read `AuthModel`, or make HTTP calls.
- Read providers **once** in `initState` and keep them in fields. Never call
  `context.read` inside a callback or `await` continuation — the widget may
  be gone.
- `core/` never imports `features/`.
- Another feature (or an old screen) uses only the module's **public
  surface**, listed in its README: the provider, the repository, the
  navigation class, a dialog or two. Nothing from `widgets/` or
  `state/*_controller.dart`.

---

## 3. Step by step

Work on a branch per module. Commit after each step so the PR history reads
like this list.

### Step 0 — Map the module (no code changes)

1. List every file of the module: screens, providers, models, helpers,
   dialogs. `grep` for the provider and model class names to find **every
   user** outside the module (billing, kiosk, reports, sync, `main.dart`,
   `sidebar_controller.dart`, `side_menu.dart`).
2. Write down the sidebar indices the module uses
   (`sideBarController.index.value = NN`).
3. Run its existing tests and note what passes — that is your baseline:

   ```bash
   flutter test
   flutter analyze > analyze_before.txt
   ```

### Step 1 — Create the folder and move the models

1. `git mv lib/models/<model>.dart lib/features/<module>/domain/models/`
   (always `git mv`, so history follows the file).
2. Fix every import (`grep -rn "models/<model>.dart" lib test`). **Do not**
   leave a re-export file at the old path — update the callers.
3. If a model imports Flutter or a provider, move that part out (usually
   into a label helper in `presentation/widgets/`).

### Step 2 — Extract the API out of the provider

Old providers mix HTTP, state and UI. Pull the HTTP out first:

```dart
typedef PurchaseHttpGet = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});

/// HTTP access to the purchase endpoints. No state.
class PurchaseApi {
  PurchaseApi({PurchaseHttpGet? httpGet, this.session = const TenantSession()})
      : _get = httpGet ?? http.get;

  final PurchaseHttpGet _get;
  final TenantSession session;

  Future<List<Purchase>> fetchPage(String token, int page) async { … }
}
```

- `http.get/post` are **injected** (tests pass a fake), API key and store id
  come from `TenantSession` (`core/network/tenant_session.dart`), never read
  `SharedPreferences` directly.
- Keep **the same URLs, query parameters, headers and error handling** as
  the old code. This is a move, not a rewrite.
- Add a `<module>_repository.dart` when there is a cache or more than one
  API call to combine; the provider then talks to the repository only.

Copy the shape from `features/suppliers/data/supplier_api.dart`.

### Step 3 — Move the provider

1. `git mv` the provider to `presentation/state/<module>_provider.dart`.
2. Make it call the API/repository instead of `http` directly. Inject the
   repository through the constructor with a default, so tests can pass a
   fake:

   ```dart
   SupplierProvider({SupplierRepository? repository})
       : repository = repository ?? SupplierRepository();
   ```

3. **Keep its public API exactly the same** — same method names,
   parameters, getters and `notifyListeners()` behaviour. Billing, sync and
   reports depend on it. (When you find a bug, fix it in its own commit and
   say so in the PR.)
4. Update the import in `main.dart` and every other user found in step 0.

### Step 4 — Split the screens

1. `git mv` each screen to `presentation/pages/<name>_page.dart` and rename
   the class to `…Page`. Update `sidebar_controller.dart`.
2. Move the page's own state (text controllers, debounce, filters shown,
   current page, export) into a `presentation/state/<page>_controller.dart`
   `ChangeNotifier`. The page creates it in `initState`, disposes it in
   `dispose`, and rebuilds with `ListenableBuilder`. Copy
   `customer_list_controller.dart` / `supplier_list_controller.dart`.
3. Cut big screens into widgets under `presentation/widgets/<page>/` — table
   columns, card, filter fields, form sections, dialogs. **Keep files under
   ~400 lines.** The limit is there to get **smaller pieces with their own
   job**, not smaller files:
   - Every piece of UI is a real widget: `class X extends StatelessWidget`
     (or `StatefulWidget`) with `Widget build(BuildContext context)`. Never a
     plain class that stores a `BuildContext` in a field and is called as
     `X(context: context, …).build()`.
   - Never split one class across files with `part` / `part of` plus
     private extensions (`extension _Section0 on MyView`), or numbered files
     (`my_view_1.dart`, `my_view_section_2.dart`). That only hides a
     2,000-line class in pieces.
   - A big controller is split by **job** — e.g. a form controller, a
     totals calculator in `domain/`, a payload builder in `data/` — not
     into `_operations_1`, `_operations_2`.
   - A helper that only opens a dialog/sheet may be a function
     (`showXDetailsDialog(context, item)`); it must check
     `context.mounted` after every `await`.
4. A controller that loads data takes a `fetch` function, not a provider,
   so it can be tested without widgets:

   ```dart
   _report = CustomerTransactionsReportController(
     fetch: (query, page) => invoices.listAllTransaction(…, updateState: false),
   );
   ```

5. If a page reads a **shared** provider only for its own list, call the
   provider with `updateState: false` (or add that flag) so it doesn't
   overwrite the list another screen shows.

### Step 5 — Navigation

1. Give each sidebar slot of the module a named constant on
   `SideBarController`, **grouped with the other named screens** (after
   the customer / supplier / report ones), with one doc line — not at the
   top of the class:

   ```dart
   /// Purchase screens in [screens]. Navigate through [PurchaseNavigation].
   /// Names always end in `ScreenIndex`.
   static const int purchasesScreenIndex = 12;
   static const int purchaseDetailsScreenIndex = 13;
   ```

   Use them in `side_menu.dart` and in the screen list comment
   (`PurchasesPage(), // 12 purchasesScreenIndex`).
2. Add `presentation/navigation/<module>_navigation.dart` with
   `openList()`, `openDetails(item)` … — the only place that sets
   `index.value` for this module. Copy `supplier_navigation.dart`
   exactly, including how it gets the controller (it may not be registered
   yet in tests or on the first frame):

   ```dart
   static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
       ? Get.find<SideBarController>()
       : Get.put(SideBarController());
   ```

### Step 6 — Tests

Tests mirror `lib/`. For every moved or new file, a test next to its twin:

| lib | test | How |
|---|---|---|
| `domain/…` | `test/features/<module>/domain/…` | plain `test()`, no widgets |
| `data/<module>_api.dart` | `…/data/<module>_api_test.dart` | fake `httpGet`/`httpPost` + `FakeTenantSession`, check URL, headers, errors |
| `presentation/state/…` | `…/presentation/state/…_test.dart` | fake repository / `fetch`; stale responses, retry, reset |
| `presentation/pages/…` | `…/presentation/pages/…_test.dart` | `testWidgets` at phone (375×812) and desktop (1440×900) sizes |

Shared helpers are in `test/test_support/`: `FakeTenantSession`,
`jsonResponse`, `FakeAppSettingsProvider`, `useSurfaceSize`,
`tapFilterToggle`, `CapturingExport`, `EnglishTranslations`. Module-only
fakes go in `test/features/<module>/support/`.

Move the module's old tests into the new folders (`git mv`) and fix their
imports; don't delete a test unless the code it tested is gone.

### Step 7 — README and clean-up

1. Write `lib/features/<module>/README.md`: what the module owns, the
   layer tree, the **public surface** other code may use, its sidebar
   indices, and how to run its tests. Copy the suppliers README's shape.
2. Delete the old folders and files that are now empty or unused.
3. `grep -rn "screens/<old_folder>\|providers/<old_provider>" lib test`
   must return nothing.
4. **Format every file you touched — including the callers** you only
   changed an import in (`main.dart`, `side_menu.dart`,
   `sidebar_controller.dart` …). Run `flutter pub get` first: without it
   `dart format` uses the wrong style and rewrites hundreds of lines.

   ```bash
   flutter pub get
   git diff --name-only origin/staging... -- '*.dart' | xargs dart format
   ```

   New imports go in the existing order (`dart:` first, then packages),
   not at the top of the file.
5. Read `git status` before every commit. Only files of this module and
   its callers belong in the PR — no scratch projects, `tmp/` folders,
   PDFs, `.env`, or generated plugin files (`linux/flutter/generated_*`,
   `windows/flutter/generated_*`; restore those with `git checkout`).

---

## 4. Things that went wrong before (avoid them)

- **Callbacks after dispose.** `context.read` inside an `await` callback
  crashed when the user left the page. Read providers in `initState`.
- **Shared list overwritten.** A tab loaded its own data through a shared
  provider and replaced the list on another screen. Use
  `updateState: false`.
- **Old response wins.** A slow request finished after a newer one and
  showed stale rows. Number each request and drop older answers (see
  `customer_transactions_report_controller.dart`).
- **Disposing what you don't own.** A page disposed an `ExportController`
  passed in from a test. Dispose only what the page created.
- **Positional sidebar list.** Inserting a screen shifted every index after
  it. Always use the named constants.
- **Translation files.** `en.json`, `ar.json`, `ml.json` use Windows line
  endings (CRLF). Add keys to all three. `test/localization_integrity_test.dart`
  also scans comments, so don't write example keys like `'x.y'.tr` in
  comments.
- **Raw SnackBars.** Use `AppToast`; `app_toast_usage_guard_test.dart`
  fails otherwise.
- **Shared UI changes inside a module PR.** The Expenses PR also changed the
  success toast colour in `lib/core/ui` — that changes every screen in the
  app. Anything in `lib/core/` (tokens, toast, kit widgets) goes in its
  **own small PR** with a before/after screenshot, even if it is one line.
- **Special cases in shared code.** `Color get background => this ==
  success ? … : …` inside `AppToastType` was replaced by a token that
  already holds the final colour (`AppColors.successToast`). If a shared
  widget needs a different value, add or change a **token**, don't branch
  on one case.
- **Unformatted callers / misplaced imports.** Only the feature folder was
  formatted; `side_menu.dart` was not, and its new import was put above
  `dart:io`. See step 7.4.
- **Committed scratch files.** A test Flutter project in `tmp/` was
  committed once and broke `flutter analyze` for everyone. See step 7.5.
- **Tests need `.env`.** `flutter test` fails with "No file or variants
  found for asset: .env" in a fresh checkout or worktree. Copy your local
  `.env` to the project root — never commit it.
- **Files split to beat the line limit.** PR #299 kept every file under 400
  lines by cutting classes into `part` files with private extensions
  (`purchase_order_form_view_1.dart` … `_8.dart`) and "views" that store a
  `BuildContext` and are called with `.build()`. They are not widgets
  (Flutter cannot rebuild or test them on their own) and the classes are as
  big as before. See step 4.3 for how to split.
- **Translations in `domain/`.** `purchase_order_totals.dart` returned
  `'…'.tr`, which pulls GetX into the domain. Domain code returns a key or
  an enum; the controller or widget translates it.
- **Raw indices outside the module.** The voucher print screen (in
  `lib/screens/`) still set `index.value = 72`. Search **all of `lib/`**
  for the module's raw indices, not only the files you moved.
- **Index names.** New constants were named `purchaseOrderListIndex`; the
  convention is `…ScreenIndex` (`purchaseOrderListScreenIndex`).
- **More modules added to an open PR.** Purchases was pushed onto the
  vouchers/purchase-returns PR while it was being reviewed, on a branch
  still named `expenses-architecture`. One module per PR, on a new branch
  named after it (`mubashir/<module>-architecture`); don't push to a PR
  that is under review except to answer review comments.
- **`git stash` is shared.** All worktrees on this machine share one stash
  list. Don't use a bare `git stash`; set work aside with a temporary
  commit on your branch instead.

---

## 5. Checklist for the architecture PR

- [ ] Module lives in `lib/features/<module>/` with `domain/`, `data/`,
      `presentation/` as in section 1 (only the folders it needs)
- [ ] Files moved with `git mv`; no re-export files left at old paths
- [ ] `domain/` has no Flutter / HTTP / storage imports
- [ ] `data/` has no widget, provider or `BuildContext` imports; HTTP is
      injectable and uses `TenantSession`
- [ ] Provider's public API unchanged; every caller (main.dart, billing,
      sync, reports…) updated and still works
- [ ] Leaf widgets get data + callbacks; no `Provider.of` / `AuthModel` /
      HTTP in them
- [ ] Sidebar indices named on `SideBarController`; one
      `<module>_navigation.dart`
- [ ] No file over ~400 lines — **without** `part` files, numbered files
      or private extensions; every UI piece extends `StatelessWidget` /
      `StatefulWidget`; no class stores a `BuildContext`
- [ ] `domain/` has no `.tr` / GetX (returns keys or enums)
- [ ] `grep -rn "index.value = <n>" lib` finds none of the module's indices
      outside `sidebar_controller.dart`; constants end in `ScreenIndex`
- [ ] The PR has exactly one module, on its own branch
- [ ] Tests mirror `lib/` under `test/features/<module>/`; API, controller
      and page tests (phone + desktop)
- [ ] `README.md` written, including the public surface
- [ ] App looks and behaves the same as before (screenshots at 375 / 1280
      before and after)
- [ ] `flutter analyze`: 0 errors and **no new warnings** compared with
      `analyze_before.txt`
- [ ] `flutter test` passes (same failures as the baseline, no new ones)
- [ ] Every touched `.dart` file formatted (after `flutter pub get`),
      callers included; new imports in order
- [ ] Sidebar constants grouped with a doc line; navigation class copies
      the `isRegistered ? find : put` getter
- [ ] Nothing in `lib/core/` changed (if it must, that is a separate PR)
- [ ] `git status` clean of scratch files, `tmp/`, `.env`, PDFs and
      generated plugin files

---

## 6. Order of work

One module per PR pair (architecture, then UI). Suggested order, smallest
first:

1. ~~Expenses~~ — **done** (PR #296): `lib/features/expenses/`, a good
   example of a module with a list, a create form and a details page
2. ~~Vouchers~~, ~~purchase returns~~, ~~purchases~~ — **done** (PR #299):
   `lib/features/vouchers/`, `purchase_returns/`, `purchases/`. Their form,
   list and detail views still use the `part`-file / `.build()` pattern —
   convert them to real widgets in each module's UI PR.
3. Sales returns, then sales
4. Stock / products
5. The remaining reports → `lib/features/reports/`

Ask for review after the first module before starting the next.
