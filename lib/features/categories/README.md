# Categories

Owns the Category List page, Add Category (16) and Edit Category (34). Category models, the shared CategoryProvider, its API/cache and billing/purchase category buckets retain their existing contracts.

## Layers and public surface

- `domain/category_list_entry.dart`: immutable list values and the existing case-insensitive name/translation substring rule.
- `data/category_list_source.dart`: injected directory/loading/listener callbacks; no provider or HTTP dependency.
- `presentation/state/category_list_controller.dart`: page-owned search, 300 ms debounce, 20-row pages, loading/error/retry and cache-update handling.
- `presentation/pages/category_list_page.dart`: binds the existing CategoryProvider's `all` scope, owns the controller/export state and routes Add/Edit through CategoryNavigation.
- `presentation/widgets/`: provider-free shared filters, table columns and mobile cards.
- `presentation/export/`: immutable snapshots of every matching category across local pages, including No, Category Name and Slug.
- Public surface: `CategoryListPage`, `CategoryNavigation.openList/openAdd/openEdit`.

Search preserves matching against all available translations, with the same order and 20-row pages as management filtering. Page-local filters do not mutate billing/sellable/purchasable category state. Reset and Refresh clear the search and ensure the directory using the existing cache policy; a directory reload keeps active search and clamps pagination. Loading blocks list/edit/export actions, including captured callbacks. Failures retain available rows and show retry feedback.

Export uses the shared ExportController and Excel service. It covers all matching categories in the loaded management directory, independently of the visible page, and captures values before asynchronous encoding/delivery. Repeated non-null category IDs stop export rather than produce a duplicated workbook. Native Windows Save As still needs manual verification. No new endpoint or printer changes.

## Add and Edit forms

- `presentation/pages/add_category_page.dart` and `edit_category_page.dart` retain the public `AddCategoryPageScreen` / `EditCategoryPageScreen` constructors and host each form's State.
- `presentation/state/category_add_form_state.dart` and `category_edit_form_state.dart` own the existing inputs, initialization, validation, submission and disposal.
- `presentation/widgets/form/` owns the existing rendering, responsive helpers and image/icon picker dialogs.
- `presentation/state/category_form_mixin.dart` retains the shared Add form controllers, language translation, tax selection and request assembly. The existing standalone Add modal also uses this mixin through its compatibility export.
- `data/category_tax_source.dart` owns the existing tax GET request, tenant/Bearer headers, active-only query and ten-second timeout, with injectable transport for tests.

The page-specific state, view and media mixins are Dart parts of their host page libraries. This keeps their private bindings and the original StatefulWidget lifecycle intact while separating responsibilities. The four legacy screen/helper paths remain compatibility exports. Create/Edit still call CategoryProvider directly; there is no new state store.

The backend-confirmed details route is `GET /api/v1/category/slug/{slug}`. The list passes the selected entry's slug, encoded as a path segment, and its ID; the provider rejects missing or mismatched details before opening Edit. The mapper accepts the slug response's `names` language records, `sellable`/`purchasable` flags and `image_url`/`icon_url`, while retaining legacy model serialization. The existing POST save request is unchanged. The prior `/api/v1/category-details?id=...` route returned 404 on demo.

Validation includes original-versus-extracted executable-token comparisons, the same six Add/Edit interaction tests against both versions, six pixel-identical Add/Edit renders (desktop, phone and Arabic), tax authentication/timeout/error/disposal tests and translation/controller lifecycle tests. Slug details tests cover transport, language/media/flag mapping, optional store context, encoded slugs and failed/mismatched responses. The focused suite passes 52 tests, with one optional preview skipped. Optional `CATEGORY_FORM_GOLDEN_MODE=baseline` with `--update-goldens` captures the six form renders to the system temporary directory; `compare` compares them.

Live demo verification on 2026-10-13: created category 917 (`qa1310`), loaded Edit using its slug, changed its name/slug to `qa13102` and enabled Purchasable. Save returned to the refreshed list; reopening Edit restored the new name/slug and both enabled flags. A separate GET returned HTTP 200 with ID 917, the saved flags and English name `qa13102`. Native media selection/upload and the full manual matrix below remain unverified.

Strict review retained these existing issues because this extraction must preserve UI and behavior:

- P2: leaving an unsaved Edit form calls `idController.clear()` after disposal and can raise a FlutterError. Successful save clears it first, so that path does not reproduce the error.
- P2: opening Edit regenerates the slug from the category name instead of retaining a custom stored slug. Saving sends the regenerated slug.
- P2: the Edit form has horizontal overflows at 375 px, reproduced in both before/after renders.
- P2: Edit still logs its authentication token in debug output. The refactor retains the original callback; avoid sharing unredacted live logs.
- P2: Add supports all active translation languages, but Edit only loads, renders and submits English, Hindi and Arabic. Malayalam and other language fields remain unsupported in Edit, as in the original implementation.

Manual verification: Add a demo category with translations, parent, flags, taxes and optional image/icon; confirm the list refreshes. Open Edit, verify its prefilled values, save changes and confirm them after reopening. Also exercise Back/Cancel, failed submissions and media selection/upload. No new UI or business rules are introduced by this extraction.

Validation: `flutter test --no-pub test/features/categories test/localization_integrity_test.dart test/core/ui/feedback/app_toast_usage_guard_test.dart`. Tests cover multilingual filters, debounce/reset/paging, concurrent initialization, sync transitions, directory replacements, errors/retry/disposal, Add/Edit routing, all-page frozen workbooks, delivery failure and phone/tablet/desktop layouts.

Before/after layout evidence at 375, 768 and 1280 px is in `docs/screenshots/category-list/`. These are widget renders with test category data, not live API or native Save As verification. Set `CATEGORY_LIST_PREVIEW=1` when running the page test to regenerate the after images in the system temporary `category-list-previews` directory.
