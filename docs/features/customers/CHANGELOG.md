# Customers Change Log

## 2026-07-16

### Contract setup

- Added backend-owned OpenAPI contract for Customer operations.
- Added a synchronized frontend copy and sync/check script.
- Documented API/UI contract mismatches discovered during comparison.

### Frontend architecture

- Extracted Customer page header.
- Extracted Customer filter panel.
- Extracted desktop Customer table.
- Extracted narrow-width Customer card list.
- Preserved the shared create-customer form.

### UX and behavior

- Preserved immediate filtering while typing.
- Added Enter-key filter submission.
- Preserved keyboard Tab navigation.
- Preserved local pagination and continuous customer numbering.
- Reworked the Customer list into a polished commerce-admin layout with a
  neutral canvas, consistent surfaces, clearer hierarchy, and responsive cards.
- Added a visible refresh action while preserving pull-to-refresh.
- Removed the fixed desktop list height so the table uses available window
  space.
- Changed the Customer page canvas to white while retaining subtle neutral
  backgrounds inside cards and metrics.
- Made the pagination surface full-width on mobile and aligned its border and
  14px corner radius with the other Customer surfaces.

### Reusable presentation

- Added feature-scoped Customer surface, avatar, type badge, metric, empty
  state, and pagination widgets.
- Reused the same visual primitives in desktop and mobile layouts.
- Kept these widgets feature-scoped until another module proves a genuinely
  shared API.

### Tests

- Added Customer filter-panel tests.
- Added desktop table/card-list tests.
- Added shared pagination tests.
- Added desktop and phone visual-regression snapshots.

### Backend compatibility

- No backend runtime code was changed during the frontend refactor.
- The initial contract comparison found response-shape and naming mismatches;
  see `FEATURE_SPEC.md`.
