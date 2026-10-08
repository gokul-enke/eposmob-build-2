# Category listing

Owns the Category List page only: search, local pagination, shared layout and Excel export. Add Category (16), Edit Category (34), category models, the shared CategoryProvider, its API/cache and billing/purchase category buckets remain unchanged.

## Layers and public surface

- `domain/category_list_entry.dart`: immutable list values and the existing case-insensitive name/translation substring rule.
- `data/category_list_source.dart`: injected directory/loading/listener callbacks; no provider or HTTP dependency.
- `presentation/state/category_list_controller.dart`: page-owned search, 300 ms debounce, 20-row pages, loading/error/retry and cache-update handling.
- `presentation/pages/category_list_page.dart`: binds the existing CategoryProvider's `all` scope, owns the controller/export state and routes Add/Edit through CategoryNavigation.
- `presentation/widgets/`: provider-free shared filters, table columns and mobile cards.
- `presentation/export/`: immutable snapshots of every matching category across local pages, including No, Category Name and Slug.
- Public surface: `CategoryListPage`, `CategoryNavigation.openList/openAdd/openEdit`.

Search preserves matching against all available translations, with the same order and 20-row pages as management filtering. Page-local filters do not mutate billing/sellable/purchasable category state. Reset and Refresh clear the search and ensure the directory using the existing cache policy; a directory reload keeps active search and clamps pagination. Loading blocks list/edit/export actions, including captured callbacks. Failures retain available rows and show retry feedback.

Export uses the shared ExportController and Excel service. It covers all matching categories in the loaded management directory, independently of the visible page, and captures values before asynchronous encoding/delivery. Repeated non-null category IDs stop export rather than produce a duplicated workbook. Native Windows Save As still needs manual verification. No new endpoint, printer or form changes.

Validation: `flutter test --no-pub test/features/categories test/localization_integrity_test.dart test/core/ui/feedback/app_toast_usage_guard_test.dart`. Tests cover multilingual filters, debounce/reset/paging, concurrent initialization, sync transitions, directory replacements, errors/retry/disposal, Add/Edit routing, all-page frozen workbooks, delivery failure and phone/tablet/desktop layouts.

Before/after layout evidence at 375, 768 and 1280 px is in `docs/screenshots/category-list/`. These are widget renders with test category data, not live API or native Save As verification. Set `CATEGORY_LIST_PREVIEW=1` when running the page test to regenerate the after images in the system temporary `category-list-previews` directory.
