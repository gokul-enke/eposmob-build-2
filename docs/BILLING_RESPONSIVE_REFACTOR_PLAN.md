# Billing — Responsive UI + Feature-First Refactor Plan

> **Status:** Proposed · **Owner:** Gokul · **Created:** 2026-06-23
> **Goal:** Make the billing screen genuinely responsive (phone / tablet / desktop)
> and move billing onto a **feature-first** folder architecture — *without breaking
> the existing flows*, guarded by a test suite written **before** the refactor.

---

## 0. TL;DR

1. Freeze current behaviour with a **characterization test suite** (logic + breakpoint contract). ✅ done
2. Introduce `core/responsive/` (single breakpoint source of truth).
3. Stand up `features/billing/` and *move* (not rewrite) existing widgets/modals into it.
4. Pull logic out of the 9.3k-line `BillingPageState` into `BillingProvider` / controllers.
5. Build one adaptive page = orchestrator + per-form-factor **layouts** over **shared widgets**.
6. Scope billing providers to the billing route; trim the global `MultiProvider`.
7. **Last:** delete confirmed dead/duplicate code (Phase 1 — deferred to the end on purpose).
8. Re-run the same test suite after every step — green stays green.

> **Execution order note:** phases are numbered by topic, but **Phase 1
> (deletion) runs LAST**, after Phase 5. See Phase 1 for the rationale.

---

## 1. Current state (baseline)

### 1.1 Routing / entry
```
main.dart (GetMaterialApp, 51 GLOBAL providers, virtual keyboard injected in builder)
  └─ BillingPageResponsive            ← only responsive decision point
       ├─ width < 650                 → BillingPageMobile
       ├─ role == 'restaurant_sales'  → RestaurantPage
       └─ else                        → BillingPage   (the monolith)
```

### 1.2 Pain points (measured)
| Symptom | Evidence |
|---|---|
| God-object page | `billing_page.dart` = **9,286 lines / 380 KB**, one `State` class |
| Logic fused into UI | **~581** field decls, **~89** methods, **115** `setState`, **191** provider lookups in one class |
| Form-factor by file-swap | separate mobile/desktop/restaurant page trees that drift |
| Magic-number responsiveness | hard-coded `< 650`, `width / 3`, `maxWidth: 120`, sidebar fraction math; `responsive.dart` helper ignored |
| Duplicate implementations | two mobile pages (`billing/billing_page_mobile.dart` **and** `mobile_screen/billing_page_mobile.dart`), two mobile widget sets (`widgets/mobile/` + `mobile_screen/widgets/`) |
| Dead code | `billing_page_desktop.dart` (commented out, 55 KB), `billing_page_restaurant.dart` (393 KB, superseded by `restaurant/`) |
| Global state soup | all **51** providers in `main.dart` `MultiProvider`; `CategoryProvider` registered twice (Get + Provider), `StockProvider` listed twice |
| Two component libs | `components/` + `newcomponents/` (e.g. `build_dialog_box` vs `custom_dialog_box`) |

### 1.3 Constraints to respect
- Orientation is **locked** in `main.dart` (`_lockOrientation`): phones = portrait, tablet/desktop = landscape.
- A **global virtual keyboard** is injected via `GetMaterialApp.builder`: phones use a `Column` (keyboard pushes content up), tablet/desktop use a `Stack` overlay. → mobile billing must be scrollable; nothing critical pinned to the bottom edge.
- `BillingPage` uses `AutomaticKeepAliveClientMixin` (state persists across nav).
- Keyboard / Tab-order accessibility is already covered by `billing_keyboard_tab_order_test.dart` — must not regress.

---

## 2. Target architecture (feature-first)

```
lib/
├── core/                         # cross-cutting, knows nothing about features
│   ├── responsive/               # breakpoints, ResponsiveWidget, BuildContext ext
│   ├── theme/                    # color_manager, font_manager, style_manager
│   ├── widgets/                  # ONE generic UI lib (merge components + newcomponents)
│   ├── services/                 # print, cash_drawer, http overrides
│   ├── helpers/ utils/ extensions/
│   └── routing/                  # central route table
│
├── features/
│   ├── billing/
│   │   ├── presentation/
│   │   │   ├── pages/            # billing_page.dart = THIN orchestrator
│   │   │   ├── layouts/          # billing_mobile_layout / billing_desktop_layout
│   │   │   ├── widgets/          # cart_table, product_grid, payment_summary, sidebar…
│   │   │   └── modals/           # checkout, payment_method, coupon, delivery…
│   │   ├── controllers/          # BillingProvider, PaymentCoordinator
│   │   ├── domain/               # pricing / discount / tax / payment RULES (pure Dart)
│   │   └── data/                 # models, repositories, datasources (hive/api)
│   ├── restaurant/   reports/   customers/   ...   # same internal shape
│
└── main.dart                     # bootstrap + ROOT (app-wide) providers only
```

**Dependency rules (enforce, don't just hope):**
- `core/` must **not** import `features/`.
- A feature may import `core/` but **not** another feature.
- `presentation/` may import `controllers/`, `domain/`, `data/`; `domain/` imports nothing Flutter.

### 2.1 Responsive model — adaptive, not parallel
- `BillingPageResponsive` keeps **only the role decision** (retail vs restaurant).
- Form factor is decided **inside** one page via a `LayoutBuilder`, swapping the **arrangement** (`layouts/`) of the **same shared widgets** (`widgets/`):
  - **Mobile** → stepped / tabbed (`PageView` or bottom-sheet): products → cart → checkout. Scrollable; keyboard-safe.
  - **Tablet/Desktop** → side-by-side product grid + cart sidebar (today's layout).
- Single breakpoint source in `core/responsive/` (start from existing 650 / 1100). Replace every magic number with it. Pick **one** signal — `MediaQuery` width *or* local `LayoutBuilder` constraints — consistently.
- Sizing: prefer `Expanded`/`Flexible`/`FractionallySizedBox`/`Wrap`/`ConstrainedBox` over fixed pixels.

---

## 3. Testing strategy (write FIRST — this is the safety net)

The existing tests already prove the right pattern: mounting the real `BillingPage` needs huge provider/Hive/SharedPreferences plumbing, so we test **patterns and logic in hermetic harnesses**, not the monolith directly.

### 3.0 Tooling to add (`dev_dependencies`)
```yaml
  mocktail: ^1.0.0        # mock providers/repositories without codegen
  golden_toolkit: ^0.15.0 # multi-device golden layout tests (optional but recommended)
```
> Keep `flutter_test`, `build_runner`, `flutter_lints` as-is. No bloc — you use `provider` + `ChangeNotifier`.

### 3.1 Test layers
| Layer | What it locks | Runs | Notes |
|---|---|---|---|
| **A. Characterization (logic)** | discount, tax, coupon, multi-unit, payment math, cart mutations | fast, no widgets | Extract pure functions into `domain/` and pin them. Highest ROI. |
| **B. Provider/controller** | `BillingProvider`/`CartProvider` state transitions | fast | Use `mocktail` for repos/datasources. Assert `notifyListeners` effects. |
| **C. Widget harness** | each extracted widget renders + callbacks fire | medium | Mirror prod wiring 1-for-1 (same style as `billing_keyboard_tab_order_test.dart`). |
| **D. Golden layout** | mobile vs tablet vs desktop arrangement | medium | `golden_toolkit` at 360×800 / 834×1112 / 1440×900. Catches layout regressions visually. |
| **E. Keyboard/Tab-order** | accessibility & focus order | medium | **Already exists** — keep green throughout. |

### 3.2 Characterization-first workflow (critical)
> A characterization test asserts **what the code does today**, even if quirky — so a behaviour-preserving refactor must keep it green.

For each behaviour we're about to touch:
1. Find the logic in `billing_page.dart`.
2. Write a test that captures current output for representative inputs (incl. edge cases: zero-qty, negative discount, max coupon, wholesale tier, multi-unit, rounding).
3. *Then* extract/move the code. Test must stay green with **no assertion changes**.

### 3.3 Coverage targets before refactor starts
- [x] Pricing/discount/tax math — characterized (`wholesale_tax_discount_test.dart`, existing).
- [x] Cart add/remove/update/clear + qty/stock guard — characterized (`local_product_provider_stock_test.dart`, `sale_unit_cart_change_test.dart`, existing).
- [x] Payment change/balance calculation — characterized (`payment_helper_normalize_test.dart`, **new**).
- [x] Money formatting / number-to-words / round-off — characterized (`amount_helper_test.dart`, **new**).
- [x] **Responsive breakpoint contract (650 / 1100)** — characterized (`responsive_breakpoints_test.dart`, **new**).
- [x] Existing keyboard + customer-history + sale-unit tests pass (re-baselined where stale).
- [ ] Coupon-specific math — deferred (coupon is persisted as `couponId` only; the
      numeric effect flows through the discount path already covered).
- [ ] Checkout → confirm / save / quotation mode branching — deferred to Phase 4
      (logic is fused into the monolith; characterize as it is extracted).
- [ ] Per-widget golden baselines — deferred to Phase 4 (see Phase 0 note).

Command:
```bash
flutter test                                 # full suite — currently +173 −0
flutter test --coverage                      # gate: coverage must not drop step-to-step
flutter test test/responsive_breakpoints_test.dart   # the responsive contract guard
```

---

## 4. Migration phases (each phase ends GREEN + committed)

> Rule: **one mechanical change per commit**, app compiles after every commit, full `flutter test` green before merging the next phase. No behaviour change in phases 0–4.

### Phase 0 — Safety net (no prod code change) — ✅ DONE (2026-06-23)
What was actually done:
- **Audited the existing suite** — discount / tax / wholesale cart math is already
  well-characterized in `wholesale_tax_discount_test.dart`; not duplicated.
- **Found and fixed a broken baseline:** 8 tests were already red (`+132 −8`)
  *before any refactor* — all confirmed **stale tests, not regressions**:
  - 6 in `stock_grouping_test.dart` — default grouping was intentionally changed
    to `kDefaultStockGroupingFields = {price, unit}`. Re-baselined to assert the
    new default AND per-field separation via explicit `activeFields`.
  - 2 in `billing_keyboard_tab_order_test.dart` — help-dialog section headers
    renamed (`GLOBAL ACTIONS`→`Global`, `FINALIZE ORDER MODAL`→`Checkout Modal`).
- **Added net-new characterization tests (32):**
  - `test/amount_helper_test.dart` — money formatting, number-to-words (EN/AR,
    INR/SAR), round-off (incl. the quirky pure-decimal "and Fifty Paise" case).
  - `test/payment_helper_normalize_test.dart` — `normalizePaidMethodsForApi`
    change/balance deduction (the one pure piece of the payment pipeline).
  - `test/responsive_breakpoints_test.dart` — **the breakpoint contract**
    (650 / 1100) for both `ResponsiveWidget` child selection and the static
    predicates. This is the contract Phase 2 must preserve.
- **Result:** full suite `+173 −0` (was `+132 −8`).
- **Tooling:** `mocktail` not yet needed (pure helpers required no mocks); add it
  in Phase 4/5 when provider/controller tests need fakes.

> **Golden tests — deliberately deferred.** Mounting the real `BillingPage`
> needs 51 providers + Hive + SharedPreferences, and the repo's test philosophy
> (see `billing_keyboard_tab_order_test.dart`) is hermetic harnesses, *not*
> mounting the monolith. Full-page goldens would be flaky and low-value now. The
> **breakpoint contract test plays the guard role** for the responsive work
> until widgets are extracted; capture per-widget goldens in **Phase 4** once
> they're standalone.

- **Exit:** ✅ suite green; contract tests committed.

### Phase 1 — Delete dead / duplicate code — ⏸️ DEFERRED: do LAST (after Phase 5)
> **Scheduling decision (2026-06-23):** deletion is intentionally moved to the
> **end** of the refactor, not the beginning. Rationale: keeping the dead trees
> in place during Phases 2–5 costs nothing, and leaving them until the new
> feature-first structure is proven avoids deleting anything we might want to
> reference while carving the monolith. Run this as the final clean-up pass.

Verified targets (import/class-reference greps done in Phase 0 follow-up):
- **Delete (confirmed dead):**
  - `lib/screens/billing/billing_page_desktop.dart` (~55 KB) — only ref is a
    commented import in `billing_page_responsive.dart:2`; declares a duplicate
    `class BillingPage`/`BillingPageState`. 0 live refs.
  - `lib/screens/billing/billing_page_restaurant.dart` (~393 KB) — 0 imports;
    `BillingPageRestaurant` referenced 0 times. Superseded by `restaurant/`.
  - `lib/screens/billing/mobile_screen/` (whole dir: `billing_page_mobile.dart`
    + `widgets/{billing_widget,home_widget,order_list_widget,payment_method_modal_wrapper}.dart`)
    — only self-referencing imports; stale duplicate of the live
    `billing/billing_page_mobile.dart` + `widgets/mobile/`.
  - The commented import line `billing_page_responsive.dart:2`.
- **Keep — verified ALIVE (do NOT delete):**
  - `lib/screens/billing/billing_page_mobile.dart` (imported by `BillingPageResponsive`).
  - `lib/screens/billing/widgets/mobile/` (imported by the live mobile page).
  - `lib/screens/billing/kitchen_master.dart` — USED: `sidebar_controller.dart:165`
    mounts `KitchenMaster()` (sidebar index 56).
- **Provider hygiene in `main.dart`:** drop the duplicate `CategoryProvider`
  registration (`Get.put` line 153 vs `ChangeNotifierProvider` line 348) and the
  duplicate `StockProvider` (lines 351 & 376). *(Safe to do now or with deletion —
  scheduled with this phase.)*
- **Gate:** `flutter analyze` clean → `flutter test` still `+173 −0` → app builds.
- **Exit:** suite green, ~520 KB removed, zero behaviour change.

### Phase 2 — `core/responsive/` (single breakpoint source)
- Create `core/responsive/breakpoints.dart` + `BuildContext` extension (`context.isMobile/isTablet/isDesktop`), seeded from existing 650/1100.
- Repoint `responsive.dart` consumers to it (keep `responsive.dart` as a thin re-export to avoid churn).
- **Don't** touch `billing_page.dart` magic numbers yet (that's Phase 4).
- **Exit:** suite green.

### Phase 2 — `core/responsive/` — ✅ DONE & STAGED (2026-06-23)
- Created `lib/core/responsive/breakpoints.dart` — `Breakpoints` (650/1100 consts +
  `isMobileWidth/isTabletWidth/isDesktopWidth/formFactorForWidth`), `DeviceFormFactor`
  enum, and `ResponsiveContext` extension (`context.isMobile/isTablet/isDesktop/formFactor`).
- `lib/responsive.dart` now delegates to + re-exports it; `ResponsiveWidget` unchanged
  behaviour, all 17 consumers untouched.
- New test `test/core_breakpoints_test.dart` pins the same contract on the new API.
- Gate: analyze clean, **179 tests** (+6).

### Phase 3 — Move billing into `features/billing/` (mechanical) — ✅ DONE & STAGED (2026-06-23)
- New tree:
  - `features/billing/presentation/pages/` ← `billing_page.dart`, `billing_page_responsive.dart`, `billing_page_mobile.dart`
  - `features/billing/presentation/widgets/` ← all of `screens/billing/widgets/` (incl. `cart/`, `mobile/`)
  - `features/billing/presentation/utils/` ← `billing_focus_orders.dart`
  - `features/billing/controllers/coordinators/` ← `payment_coordinator.dart`
- All moves via `git mv` (rename-tracked); import paths rewritten project-wide.
- `billing_page_responsive.dart` now uses `Breakpoints.isMobileWidth(...)` instead of the
  hard-coded `< 650` (single-source adoption).
- **Not moved (intentional):** `restaurant/` (separate feature), `kitchen_master.dart`
  (alive), and the dead `billing_page_desktop.dart` / `billing_page_restaurant.dart` /
  `mobile_screen/` (deleted in the final Phase 1).
- Gate: **0 analyzer errors**, **179 tests** green. Pure relocation — no logic change.

### Phase 4 — Carve the monolith (one widget at a time) — 🔄 IN PROGRESS (safe increments only)
**Done & staged so far:**
- ✅ Extracted pure sidebar-width math → `presentation/utils/billing_sidebar_metrics.dart`
  (`BillingSidebarMetrics.clampedWidth`), removed the 3 inline constants, page now
  delegates. Covered by `test/billing_sidebar_metrics_test.dart` (behaviour-preserving).
  Gate: 0 errors, **184 tests**.

**Why the REST of Phase 4 is not auto-executed:** the high-value extractions (cart table,
product grid, sidebar, action buttons) rewire widget state/context and **cannot be verified
without running the app** (see below). Only *provably pure* logic is safe to lift in a batch
run; those are nearly exhausted (most remaining helpers read providers/`context`, or their
model types live in provider files, which would violate the `domain/` dependency rule).
The widget/state extractions must proceed **one piece at a time, verified in the running app.**

> **Why full Phase 4 was NOT auto-executed in the batch run:** unlike Phases 2–3 (pure,
> compiler-verifiable relocation), every Phase-4 extraction is *semantic surgery* on a
> 9,286-line / 581-field / 115-`setState` god-object in a **money-handling POS**. There is
> **no behavioural/widget test coverage of the monolith** (by design — it can't be mounted
> without 51 providers + Hive), and the billing UI can't be exercised from `flutter test`.
> So a "compile-passing" extraction could silently break real billing flows with no signal.
> This phase must be done **one widget at a time, each reviewed and verified in the running
> app** — exactly as the steps below state. Batch-automating it would be reckless.
For each block (recommended order): **cart table → product grid → payment summary → customer input → sidebar → action buttons → each modal**:
1. Extract into `presentation/widgets/<x>.dart` taking typed inputs + callbacks.
2. Move its business logic into `BillingProvider`/`domain/` (kill the local `setState`).
3. Replace magic numbers with `core/responsive` values.
4. Run suite + goldens. Commit. Next widget.
- **Exit per widget:** suite green, golden unchanged (or intentionally updated with review).

### Phase 5 — Adaptive layouts + thin page
- Build `presentation/layouts/billing_mobile_layout.dart` (stepped/tabbed, scrollable, keyboard-safe) and `billing_desktop_layout.dart` (side-by-side) from the shared widgets.
- Reduce `billing_page.dart` to an orchestrator: pick role (kept in `BillingPageResponsive`), pick layout via `LayoutBuilder`, wire providers. Target < ~400 lines.
- Add **new** golden tests for mobile/tablet/desktop arrangements (Layer D).
- **Exit:** suite + goldens green; manual smoke on phone/tablet/desktop.

### Phase 6 — Scope providers
- Wrap the billing route in a feature-local `MultiProvider` for billing-only providers (`BillingProvider`, `CartProvider`, `Cart`, `DiscountProvider`, restaurant `Menu/Order/Table`…).
- Keep only genuinely app-wide providers global in `main.dart` (auth, settings, language, session, font).
- **Exit:** suite green; verify lazy creation (cheaper startup) and no "provider not found" at runtime.

### Phase 7 — Consolidate component libs (optional, follow-up)
- Merge `components/` + `newcomponents/` into `core/widgets/`; collapse duplicate dialogs. Codemod imports.

---

## 5. Risk register
| Risk | Mitigation |
|---|---|
| Hidden behaviour in `setState` side effects | Characterization tests (Phase 0) before any extraction |
| `AutomaticKeepAliveClientMixin` state assumptions | Verify keep-alive still holds after orchestrator split; add a nav-retention widget test |
| Virtual keyboard overlap on mobile | Golden + manual test at phone size with keyboard open; scrollable layout |
| Provider scoping breaks a far-away screen | Move app-wide providers to global; integration smoke after Phase 6 |
| Golden flakiness across machines | Pin font + `golden_toolkit` device configs; run goldens in CI only |
| Big-bang temptation | Enforce "one mechanical change per commit, suite green between" |

---

## 6. Definition of done
- [ ] `billing_page.dart` is an orchestrator (< ~400 lines); logic lives in `controllers/` + `domain/`.
- [ ] One adaptive page renders correctly at phone / tablet / desktop (golden-verified).
- [ ] No duplicate mobile/desktop/restaurant page trees; dead files deleted.
- [ ] Single breakpoint source; zero billing magic numbers.
- [ ] Billing providers scoped to the feature; global list trimmed; no double registrations.
- [ ] Full `flutter test` green incl. existing keyboard/customer/sale-unit suites; coverage ≥ pre-refactor.
- [ ] `features/billing/` follows the §2 structure and dependency rules; pattern documented for new pages.

---

## 7. New-page checklist (apply from day one)
1. `features/<name>/` with `presentation/{pages,layouts,widgets,modals}`, `controllers/`, `domain/`, `data/`.
2. Page = orchestrator only; layouts per form factor; widgets shared.
3. Logic in controller/domain, not the widget.
4. Use `core/responsive` breakpoints — no magic numbers.
5. Scope providers to the route.
6. Tests: Layer A (logic) + C (widgets) + D (golden) before merge.
