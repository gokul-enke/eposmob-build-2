# Reusable Feature Refactor Plan

> **Purpose:** A repeatable checklist for safely refactoring any CloudPOS
> frontend feature, such as Customers, Suppliers, Products, Transactions,
> Reports, Purchases, or Settings.
>
> **Project stack:** Flutter frontend, Provider/ChangeNotifier, selected GetX
> controllers, HTTP APIs, Hive/SharedPreferences, Laravel backend, OpenAPI
> contracts.
>
> **Primary rule:** Improve one small boundary at a time. Preserve existing
> behavior unless the current step explicitly changes behavior and adds tests.

---

## 1. How to use this document

For every feature refactor:

1. Copy the **Feature Refactor Worksheet** at the end of this document into the
   feature's documentation folder.
2. Complete the current-state inventory before changing code.
3. Create a clean Git checkpoint.
4. Pick one low-risk component or behavior.
5. Add characterization tests when behavior is not already protected.
6. Refactor or change that one thing.
7. Analyze, test, visually verify when needed, and commit.
8. Reassess the next highest-value step.
9. Stop when the agreed feature slice is clean enough.

Do not treat this plan as permission to rewrite an entire feature.

---

## 2. Refactor operating loop

Use this loop after every completed step:

```text
Inspect
  ↓
Choose one small change
  ↓
State what must not change
  ↓
Add or identify safety tests
  ↓
Implement
  ↓
Format + analyze + test
  ↓
Review the diff
  ↓
Commit
  ↓
Ask: is another step genuinely valuable?
  ├── Yes → repeat
  └── No  → stop and document the handoff
```

### Stop immediately when

- The next change depends on an unfinished backend contract.
- The next change expands into a different feature slice.
- A shared form/widget has many unknown consumers.
- Existing behavior cannot be established safely.
- The work would require guessing business rules.
- A clean boundary has already been achieved and further abstraction has no
  current consumer.

---

## 3. Phase A — Define scope and exclusions

Before reading implementation details, write down:

### In scope

- Which page, tab, modal, list, form, or user flow?
- Desktop, tablet, mobile, or all form factors?
- Presentation-only refactor or behavior change?
- API integration included or excluded?
- Offline/cache behavior included or excluded?

### Explicitly out of scope

Examples:

- Shared create/edit form used by several features
- Profile/details page
- Backend endpoint changes
- State-management migration
- Visual redesign
- Navigation rewrite
- Existing legacy pages still used elsewhere

### Success statement

Write one sentence:

> Refactor the Supplier list presentation into focused components while
> preserving API behavior, filters, pagination, keyboard navigation, responsive
> breakpoints, and the shared Supplier form.

If the success statement contains several unrelated outcomes, split the work.

---

## 4. Phase B — Create a safe baseline

### Git checks

- [ ] Run `git status --short`.
- [ ] Identify all existing uncommitted changes.
- [ ] Confirm which changes belong to the user.
- [ ] Commit or intentionally preserve the existing changes.
- [ ] Do not mix unrelated changes into the refactor commit.

### Build and test baseline

- [ ] Confirm the page currently opens.
- [ ] Run relevant existing tests.
- [ ] Record pre-existing analyzer warnings.
- [ ] Record known runtime bugs separately.
- [ ] Do not claim a refactor caused a failure that existed before it.

Suggested commands:

```bash
flutter analyze <relevant files>
flutter test <relevant tests>
flutter test test/widget_test.dart
```

Use the full test suite when the change affects shared infrastructure.

---

## 5. Phase C — Map the current feature

Do this before moving files.

### Entry and navigation

- [ ] Sidebar/menu item
- [ ] Route or numeric sidebar index
- [ ] Permission required to see the feature
- [ ] Role-specific variations
- [ ] Parent layout or drawer
- [ ] How details/profile pages are opened
- [ ] How selected records are passed

### UI files

- [ ] Main page
- [ ] Mobile page
- [ ] Tablet/narrow layout
- [ ] Desktop table
- [ ] Cards/list rows
- [ ] Filters
- [ ] Pagination
- [ ] Loading/empty/error widgets
- [ ] Forms/modals
- [ ] Shared widgets used by other features

### State and logic

- [ ] Provider/controller
- [ ] Loading state
- [ ] Error state
- [ ] Selected record
- [ ] Current page/total pages
- [ ] Active filters
- [ ] Sorting
- [ ] Local cache
- [ ] Offline fallback
- [ ] Refresh behavior

### Data integration

- [ ] Endpoints
- [ ] HTTP methods
- [ ] Authentication headers
- [ ] Tenant/store headers or parameters
- [ ] Request/query parameters
- [ ] Response shape
- [ ] Model/parser
- [ ] Nullability and defaults
- [ ] Backend validation

### Lifecycle resources

- [ ] `TextEditingController`
- [ ] `FocusNode`
- [ ] `ScrollController`
- [ ] `AnimationController`
- [ ] Timers/debouncers
- [ ] Streams/subscriptions
- [ ] Listeners
- [ ] Hive boxes or local resources

Every owned resource must have a clear disposal strategy.

---

## 6. Phase D — Create a behavior inventory

The goal is to know what must remain unchanged.

### List and table behavior

- [ ] Visible columns
- [ ] Column order
- [ ] Field-to-column mapping
- [ ] Number/date/currency formatting
- [ ] Positive/negative/zero colors
- [ ] Status badges
- [ ] Row numbering
- [ ] Row actions
- [ ] Selection behavior
- [ ] Sorting behavior

### Search and filters

- [ ] Filter names
- [ ] Filter types
- [ ] Local or server-side filtering
- [ ] Case sensitivity
- [ ] Exact or partial matching
- [ ] Combined filter behavior
- [ ] Reset behavior
- [ ] Search while typing
- [ ] Search on Enter
- [ ] Debounce behavior
- [ ] Whether filtering resets to page 1

### Pagination

- [ ] Page size
- [ ] Local or server-side
- [ ] Previous/Next boundaries
- [ ] Continuous row numbering
- [ ] Empty last-page behavior
- [ ] What happens after filters change
- [ ] What happens after refresh

### UI states

- [ ] Initial state
- [ ] Loading state
- [ ] Empty state
- [ ] Filtered-empty state
- [ ] Error state
- [ ] Offline/cache state
- [ ] Refreshing state
- [ ] Permission-denied state

### User actions

- [ ] Add
- [ ] View
- [ ] Edit
- [ ] Delete
- [ ] Refresh
- [ ] Export/print
- [ ] Open profile/details
- [ ] Back/cancel

Write characterization tests for behavior that is important but unclear.

---

## 7. Phase E — API and contract review

Frontend refactoring must not hide API disagreements.

### Compare frontend and backend

- [ ] Endpoint path and method match.
- [ ] Query parameter names match.
- [ ] Request body field names match.
- [ ] Required/optional fields match.
- [ ] Response nesting matches.
- [ ] Pagination shape matches.
- [ ] Field casing matches (`snake_case` versus `camelCase`).
- [ ] IDs needed by the UI are returned.
- [ ] Types match (`string`, `integer`, `number`, `boolean`).
- [ ] Nullability matches.
- [ ] Empty-result behavior matches.
- [ ] Error status codes and bodies match.

### Contract ownership

```text
Backend OpenAPI contract → API source of truth
Frontend synchronized copy → local reference
Feature specification → UI/UX interpretation
TODO/Jira → unfinished coordination work
Changelog → completed changes
```

### When a mismatch is found

1. Document it.
2. Add a TODO/Jira item.
3. Mark dependent frontend work blocked.
4. Do not guess the future backend shape.
5. Continue only with frontend work independent of the mismatch.

---

## 8. Phase F — Decide the target boundary

For a typical list feature, the target presentation structure is:

```text
FeaturePage
├── FeaturePageHeader
├── FeatureFilterPanel
├── FeatureCardList
├── FeatureDesktopTable
├── PaginationControl
└── Feature states
    ├── Loading
    ├── Empty
    └── Error
```

The page should coordinate:

- Data source/state
- Responsive layout choice
- Navigation callbacks
- Modal/form opening
- Pagination callbacks
- Refresh

Child components should display data and emit callbacks.

### Good component boundary

```dart
FeatureDesktopTable(
  records: state.records,
  currentPage: state.currentPage,
  itemsPerPage: state.itemsPerPage,
  onViewRecord: controller.openRecord,
)
```

### Warning signs

- Child widget reads several global providers directly.
- Child widget constructs API payloads.
- Child widget changes sidebar indexes itself.
- Child widget shows business-specific dialogs without callbacks.
- Parent passes more than roughly 10 unrelated primitive parameters.
- A “generic” widget contains feature names and special cases.

---

## 9. Phase G — Extraction order

Use the smallest useful order:

1. **Page header**
   - Title
   - Primary action
   - Optional refresh/export action

2. **Filter panel**
   - Text fields
   - Dropdowns
   - Search/reset callbacks
   - Keyboard submission

3. **Desktop table**
   - Header
   - Rows
   - Formatting
   - Row actions
   - Empty state when structurally coupled

4. **Responsive card list**
   - Cards
   - Formatting
   - Actions
   - Empty state

5. **Shared pagination**
   - Extract only if already repeated or clearly cross-feature.

6. **Loading/error/empty widgets**
   - Promote to shared widgets only after repeated patterns are confirmed.

7. **Page orchestrator**
   - Becomes easier to read after child extraction.

Do not extract an individual `TableRow` as a normal widget; Flutter `Table`
requires `TableRow` objects. Extract the complete table instead.

---

## 10. Architecture checklist

### Presentation layer

- [ ] Widgets display state and emit callbacks.
- [ ] Widgets do not call raw HTTP APIs.
- [ ] Widgets do not parse JSON.
- [ ] Widgets do not know API URLs.
- [ ] Widgets avoid direct Hive/SharedPreferences access.
- [ ] Page orchestration remains understandable.
- [ ] Large widget methods are extracted by responsibility.

### State/controller layer

- [ ] Owns loading/error/filter/page state.
- [ ] Exposes immutable or internally consistent state.
- [ ] Avoids duplicate instances across Provider/GetX.
- [ ] Does not depend on UI styling.
- [ ] Avoids `BuildContext` where practical.
- [ ] Does not show dialogs/snackbars directly unless legacy behavior is
      intentionally retained temporarily.

### Domain layer

- [ ] Business calculations are pure Dart where practical.
- [ ] Rules are named and tested.
- [ ] UI colors/layout are not mixed with business rules.
- [ ] Domain code does not import Flutter.

### Data layer

- [ ] Repository owns data-source choice.
- [ ] API client owns HTTP details.
- [ ] Cache data source owns Hive/local persistence.
- [ ] Request and response mapping are testable.
- [ ] API errors map to predictable application failures.

### Incremental rule

Do not create all layers merely to satisfy a folder diagram. Introduce a layer
when it removes a real mixed responsibility or enables testing/reuse.

---

## 11. Reusability decision rules

### Keep feature-specific when

- It is used only by one feature.
- Its language or behavior is domain-specific.
- Generalizing it requires flags and special cases.
- The pattern has not repeated yet.

### Promote to shared when

- The same interaction appears in at least two or three features.
- Styling and behavior are genuinely identical.
- The API can be simple and feature-neutral.
- Shared ownership will reduce duplication rather than hide differences.

### Likely shared candidates

- Search text field
- Filter dropdown
- Pagination control
- Empty/error/loading state
- Standard page header
- Responsive data container
- Focusable action button
- Date-range filter

### Avoid

- `CommonWidget1`
- `UniversalTable` with dozens of flags
- Feature-specific logic inside `core/widgets`
- Wrappers that only rename an existing Flutter widget
- Premature repository/use-case interfaces with one implementation and no
  testing or substitution need

---

## 12. Keyboard and focus checklist

Refer to `docs/KEYBOARD_NAVIGATION_GUIDE.md` for project-specific patterns.

### Traversal

- [ ] Tab order follows visual/user-workflow order.
- [ ] Shift+Tab moves backward correctly.
- [ ] Focus does not enter decorative elements.
- [ ] Hidden widgets are not focusable.
- [ ] Expandable filters preserve logical focus order.
- [ ] Modal focus stays trapped inside the modal where appropriate.
- [ ] Closing a modal returns focus to a sensible control.

### Actions

- [ ] Enter submits a search/form where expected.
- [ ] Space/Enter activates focused buttons.
- [ ] Escape closes modal/filter panels where expected.
- [ ] Arrow keys work for lists/dropdowns where supported.
- [ ] Keyboard shortcuts do not conflict with text entry.

### Visual focus

- [ ] Focus is visibly indicated.
- [ ] Focus glow/border does not shift layout.
- [ ] Focus and hover states are distinguishable.
- [ ] Disabled controls do not appear actionable.

### Lifecycle

- [ ] Every owned `FocusNode` is disposed.
- [ ] Dynamic row focus nodes are disposed when rows are removed.
- [ ] No delayed callback requests focus after disposal.
- [ ] Use `mounted` checks after asynchronous work.

### Tests

- [ ] Tab order
- [ ] Enter submission
- [ ] Button keyboard activation
- [ ] Modal focus behavior
- [ ] Important keyboard shortcuts

---

## 13. Responsive design checklist

### Breakpoints

- [ ] Use project breakpoint constants where available.
- [ ] Document existing thresholds before changing them.
- [ ] Distinguish screen width from local container width.
- [ ] Do not introduce a new magic breakpoint without justification.

### Layout

- [ ] Test narrow phone.
- [ ] Test wide phone/landscape if supported.
- [ ] Test tablet.
- [ ] Test desktop.
- [ ] Test resized desktop window.
- [ ] Avoid unnecessary fixed heights.
- [ ] Prefer `Expanded`, `Flexible`, `Wrap`, and constraints.
- [ ] Long text does not overflow.
- [ ] Tables can scroll when required.
- [ ] Cards remain readable at the narrow boundary.

### Input and keyboard

- [ ] System/virtual keyboard does not cover critical actions.
- [ ] Forms scroll to focused fields.
- [ ] Bottom actions remain reachable.

### Platform behavior

- [ ] Mouse scrolling/dragging
- [ ] Trackpad
- [ ] Touch
- [ ] Desktop keyboard
- [ ] Mobile keyboard
- [ ] Platform-specific plugins remain guarded

---

## 14. Accessibility checklist

- [ ] Touch targets are adequately sized.
- [ ] Buttons have understandable labels.
- [ ] Icon-only actions have tooltips/semantics where needed.
- [ ] Text contrast is sufficient.
- [ ] Information is not communicated by color alone.
- [ ] Screen-reader order follows visual order.
- [ ] Empty/error/loading states are understandable.
- [ ] Text scaling does not break the layout.
- [ ] Controls expose selected/disabled state.

---

## 15. Forms checklist

Forms are high-risk because they often have many consumers.

### Before touching a form

- [ ] Search every import and invocation.
- [ ] Identify modal/page/billing/profile consumers.
- [ ] Document request payload.
- [ ] Document validation.
- [ ] Document keyboard order.
- [ ] Document defaults and conditional fields.
- [ ] Document create versus edit differences.

### Form architecture

- [ ] Controllers have one clear owner.
- [ ] Controllers and focus nodes are disposed.
- [ ] Validation messages map to fields.
- [ ] Submission cannot run twice accidentally.
- [ ] Loading disables duplicate actions.
- [ ] Cancel does not mutate persisted state.
- [ ] Success refreshes the correct list/detail view.
- [ ] Backend errors remain visible and actionable.

### Shared forms

If a form is shared across several features, initially keep it untouched while
refactoring surrounding list presentation. Refactor it as a dedicated project
with its own characterization tests.

---

## 16. Loading, error, empty, and offline checklist

- [ ] Initial loading differs from background refresh when useful.
- [ ] Empty dataset differs from filtered-empty dataset.
- [ ] Error does not display as empty data.
- [ ] Retry action exists where appropriate.
- [ ] Cached/offline data is clearly understood.
- [ ] Refresh does not erase useful cached data before success.
- [ ] Timeouts are handled.
- [ ] Authentication/tenant errors are distinguishable.
- [ ] Errors are logged without leaking tokens or sensitive data.

---

## 17. Performance checklist

- [ ] Search does not trigger unnecessary API calls.
- [ ] API search uses debounce when needed.
- [ ] Enter can trigger immediate search.
- [ ] Large datasets use server-side pagination.
- [ ] Avoid loading “all records” unless explicitly bounded.
- [ ] Avoid repeated API calls from `build()`.
- [ ] Use `Consumer`/selectors at the smallest useful boundary.
- [ ] Avoid rebuilding complete pages for one field.
- [ ] Lists use builders.
- [ ] Images are sized/cached appropriately.
- [ ] Expensive calculations are outside widget build methods.
- [ ] Debug logging is removed from hot build paths.

---

## 18. Security and privacy checklist

- [ ] Tokens/API keys are not printed.
- [ ] Sensitive customer information is not logged unnecessarily.
- [ ] Secrets are not committed.
- [ ] Tenant/store scope is included correctly.
- [ ] Role permission checks remain intact.
- [ ] UI permission hiding is not treated as backend authorization.
- [ ] Validation exists on both frontend and backend where appropriate.
- [ ] Cached sensitive data has intentional lifecycle/clear behavior.

---

## 19. Testing checklist

### Characterization tests

Capture existing behavior before moving logic.

- [ ] Current formatting
- [ ] Current calculations
- [ ] Current filter behavior
- [ ] Current navigation callback
- [ ] Current pagination
- [ ] Current responsive threshold

### Unit tests

- [ ] Pure business rules
- [ ] Request mapping
- [ ] Response parsing
- [ ] Filter state
- [ ] Pagination calculations
- [ ] Repository behavior with fake data sources

### Widget tests

- [ ] Controls render
- [ ] Input callbacks fire
- [ ] Enter submission
- [ ] Tab order
- [ ] Dropdown selection
- [ ] Reset
- [ ] Empty/loading/error state
- [ ] Row/card action returns correct record
- [ ] Continuous numbering
- [ ] Responsive component selection

### Integration/contract tests

- [ ] Backend response matches OpenAPI.
- [ ] Frontend parser accepts documented response.
- [ ] Required IDs and fields are present.
- [ ] Error shapes are understood.

### Visual checks

Use screenshots/golden tests when layout relationships matter:

- [ ] Phone
- [ ] Tablet
- [ ] Desktop
- [ ] Long text
- [ ] Empty state
- [ ] Loading state
- [ ] Error state

---

## 20. Documentation checklist

Feature folder:

```text
docs/features/<feature>/
├── README.md
├── FEATURE_SPEC.md
├── TODO.md
└── CHANGELOG.md
```

### `README.md`

- [ ] Purpose
- [ ] Ownership
- [ ] Relevant files
- [ ] Links to contract/spec/TODO/changelog

### `FEATURE_SPEC.md`

- [ ] Endpoints
- [ ] Request parameters
- [ ] Response-to-UI mapping
- [ ] Filters
- [ ] Columns/cards
- [ ] Colors/formatting
- [ ] Keyboard behavior
- [ ] Responsive behavior
- [ ] Loading/error/empty behavior
- [ ] Business rules
- [ ] Known mismatches

### `TODO.md`

- [ ] Technical ID
- [ ] Priority
- [ ] Owner
- [ ] Jira reference
- [ ] Status
- [ ] Blocking notes
- [ ] Completion criteria

### `CHANGELOG.md`

- [ ] Completed API changes
- [ ] Completed frontend changes
- [ ] Compatibility notes
- [ ] Migration/deprecation notes

---

## 21. Verification gates

Every step must pass the relevant gates before commit.

### Minimum gate

```bash
dart format <changed dart files>
flutter analyze <changed/relevant files>
flutter test <focused tests>
git diff --check
```

### Shared component gate

Also run all known consumers or the full test suite.

### Platform gate

For platform-specific changes:

```bash
flutter build macos
flutter build windows
flutter build apk
```

Run only the relevant available platform locally; CI should cover the rest.

### Runtime visual gate

- [ ] Open the actual page.
- [ ] Try mouse/touch.
- [ ] Try keyboard Tab/Enter/Escape.
- [ ] Resize the window.
- [ ] Try empty and populated data.
- [ ] Try first and last pagination pages.

---

## 22. Commit strategy

Use focused commits:

```text
test: characterize supplier filters
refactor: extract supplier page header
refactor: extract supplier filter panel
refactor: extract supplier desktop table
refactor: extract supplier card list
test: cover supplier list components
fix: dispose supplier filter controllers safely
docs: add supplier feature contract
```

### Commit rules

- [ ] One conceptual change per commit.
- [ ] Tests and implementation may be together for a small behavior change.
- [ ] Safety tests may be committed before production refactoring.
- [ ] Do not combine backend contract changes with unrelated UI cleanup.
- [ ] Review `git diff --stat` and `git diff --check`.
- [ ] Never include unrelated user changes.

---

## 23. Definition of done

A feature slice is complete when:

- [ ] The agreed scope is implemented.
- [ ] Explicit exclusions remain untouched.
- [ ] The page has understandable component boundaries.
- [ ] Existing behavior is preserved or intentional changes are documented.
- [ ] Keyboard navigation is verified.
- [ ] Responsive behavior is verified.
- [ ] Loading, empty, and error states are handled.
- [ ] Controllers/focus nodes/resources are disposed.
- [ ] Focused tests cover important behavior.
- [ ] Analyzer has no new issues.
- [ ] API mismatches are fixed or tracked as blocked work.
- [ ] Feature documentation is current.
- [ ] Changes are committed in focused checkpoints.
- [ ] The work stops before expanding into a separate feature slice.

“Done” does not mean the entire feature has perfect clean architecture. It means
the selected slice is safer, clearer, tested, documented, and ready for the next
independent slice.

---

## 24. Feature Refactor Worksheet

Copy this section into the feature documentation before starting.

```markdown
# <Feature> Refactor Worksheet

## Goal

## In scope

- 

## Out of scope

- 

## Entry/navigation

- Sidebar/menu:
- Permission:
- Route/index:
- Detail navigation:

## Current files

- Page:
- Mobile page:
- Provider/controller:
- Models:
- Forms/modals:
- Shared widgets:

## API contract

- List endpoint:
- Create endpoint:
- Edit endpoint:
- Authentication:
- Pagination shape:
- Known mismatches:

## Current UI

- Header:
- Filters:
- Table columns:
- Card fields:
- Actions:
- Pagination:

## Behavior to preserve

- Keyboard:
- Responsive:
- Loading:
- Empty:
- Error:
- Offline/cache:

## Resources to dispose

- Controllers:
- Focus nodes:
- Other:

## Existing tests

- 

## Planned small steps

1. 
2. 
3. 

## Stop condition

## Open backend/frontend coordination

| ID | Owner | Task | Jira | Status |
|---|---|---|---|---|
```

---

## 25. Related project guides

- `docs/ARCHITECTURE_REVIEW.md`
- `docs/KEYBOARD_NAVIGATION_GUIDE.md`
- `docs/BILLING_RESPONSIVE_REFACTOR_PLAN.md`
- `docs/features/<feature>/FEATURE_SPEC.md`
- `contracts/openapi/<feature>.yaml`

