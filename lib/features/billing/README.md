# features/billing

Feature-first home for the billing/POS screen. See
`docs/BILLING_RESPONSIVE_REFACTOR_PLAN.md` for the full migration plan and phase
status.

## Structure
```
features/billing/
├── presentation/
│   ├── pages/      # entry/orchestrator widgets (billing_page*, responsive, mobile)
│   ├── widgets/    # shared building blocks (cart, modals, sidebar, summary, …)
│   ├── utils/      # presentation-only helpers (focus order constants, …)
│   └── layouts/    # (Phase 5) per-form-factor arrangements over shared widgets
├── controllers/    # coordinators + (future) BillingProvider-level orchestration
├── domain/         # (Phase 4) pure billing rules (pricing/discount/tax/payment)
└── data/           # (Phase 4) models, repositories, datasources
```

## Dependency rules (enforce these)
- `core/` must **not** import `features/`.
- This feature may import `core/` but **not** another feature.
- `presentation/` may import `controllers/`, `domain/`, `data/`.
- `domain/` imports no Flutter — pure Dart, unit-testable without a widget.

## Status (2026-06-23)
- ✅ Phase 2 — single breakpoint source in `core/responsive/`.
- ✅ Phase 3 — pages/widgets/utils/coordinators relocated here (pure move).
- ⏳ Phase 4+ — carving `presentation/pages/billing_page.dart` (9.3k-line monolith)
  into `widgets/` + `domain/` is **incremental, human-verified** work: the page
  fires network/connectivity calls in `initState`, so it cannot be mounted in a
  hermetic widget test. Extract one piece at a time and verify in the running app.

## Adding a new feature page
Mirror this shape from day one: page = orchestrator, layouts per form factor,
widgets shared, logic in `controllers/`/`domain/`, breakpoints from
`core/responsive`, providers scoped to the route.
