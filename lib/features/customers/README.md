# features/customers

Everything about customers: the list, the profile (with its tabs), the one
create/edit form, addresses, and the app-wide customer directory that
billing, kiosk, sales and reports read.

This feature is the **reference implementation** for the feature
architecture and for the shared UI kit in `lib/core/ui/`. When you move
another feature, copy this layout.

## Layers

```text
features/customers/
├── domain/                  pure Dart: no Flutter, no HTTP, no storage
│   ├── models/customer_list.dart   CustomerListModelData, Address, CustomerOrder…
│   ├── balance_filter.dart         BalanceFilter enum (+ legacy string mapping)
│   ├── customer_filter.dart        CustomerFilter: name/email/phone/balance rules
│   └── customer_display.dart       CustomerNames (unnamed rules), CustomerType
├── data/                    talks to the outside world, no UI state
│   ├── customer_api.dart           HTTP only (injectable get/post + TenantSession)
│   ├── customer_cache.dart         Hive offline copy, per store
│   ├── customer_payloads.dart      CustomerFields → request bodies
│   └── customer_repository.dart    API + cache: list/snapshot/create/update/lookups/addresses
└── presentation/
    ├── state/               ChangeNotifiers; no widgets
    │   ├── customer_provider.dart        app-wide directory + selection (registered in main.dart)
    │   ├── customer_list_controller.dart list page inputs (debounced search)
    │   ├── customer_form_controller.dart create/edit form (+ values, edit changes, location)
    │   ├── customer_profile_tab.dart     profile tab enum
    │   └── customer_{orders,transactions,address,chat}_controller.dart
    ├── navigation/customer_navigation.dart   the only code that knows sidebar indices
    ├── pages/               screens the shell shows
    │   ├── customers_list_page.dart      ListPageScaffold
    │   ├── customer_profile_page.dart    DetailPageScaffold
    │   └── add_customer_page.dart
    └── widgets/             leaf widgets: data + callbacks in, no provider lookups
        ├── list/  form/  profile/  address/  purchase_history/
        ├── customer_avatar.dart   (CustomerAvatar, CustomerTypeBadge)
        └── customer_labels.dart   (translated display text)
```

## Dependency rules

- `domain/` imports nothing outside `domain/` (and `dart:`).
- `data/` imports `domain/`, `core/`, `resources/app_url.dart` and packages
  (http, hive) — never widgets or providers.
- `presentation/state/` imports `data/`, `domain/`, `core/`.
- Pages and tabs read providers and own their controllers. **Leaf widgets
  never call `Provider.of`, read `AuthModel`, or make HTTP calls** — they get
  data and callbacks.
- Read providers once in `initState` (or `build`), never inside callbacks
  that can run after the widget is gone.
- `core/` never imports `features/`.
- Other features use the public surface only: `CustomerProvider`,
  `CustomerRepository` (one-off lookups — don't create a throwaway
  `CustomerProvider()`), `CustomerNavigation`, `showAddCustomerDialog`,
  `AddCustomerMobilePage`'s form, `showCustomerAddressFormDialog`,
  `CustomerPurchaseHistoryDialog`.

## UI rules

- Build screens from `package:pos_machine/core/ui/ui.dart`: `ListPageScaffold`,
  `DetailPageScaffold`, `PageHeader`, `FilterPanel`, `AppDataTable`,
  `AppCardList`, `AppAdaptiveList`, `AppPaginationBar`, `SectionCard`,
  `AppTextField`, `FormActionsBar`, `AppDialog`, …
- Colours, spacing, radii and text styles come from `AppColors`,
  `AppSpacing`, `AppRadius`, `AppTextStyles`. No `Color(0x…)` literals and no
  breakpoint numbers in feature code.
- All visible text goes through `.tr` with keys present in `en`, `ar` and
  `ml` (`test/localization_integrity_test.dart` enforces en/ar).
- Keep files under ~400 lines; split into section widgets.

## Tests

Tests mirror `lib/`:

```text
test/features/customers/
├── domain/        filter, balance, display, models
├── data/          api (fake HTTP), cache (temp Hive), payloads, repository
├── presentation/
│   ├── state/     provider, list/form/orders/transactions/address/chat controllers
│   ├── navigation/
│   ├── pages/     list page, profile page (phone + desktop sizes)
│   └── widgets/   list/, form/, profile/, address/, purchase_history/
└── support/       FakeCustomerRepository, FakeTenantSession, JSON helpers
test/core/ui/…     one test file per shared widget
```

Run them with:

```bash
flutter test test/features/customers test/core
```
