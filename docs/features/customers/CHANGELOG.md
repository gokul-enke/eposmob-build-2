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

### Tests

- Added Customer filter-panel tests.
- Added desktop table/card-list tests.
- Added shared pagination tests.

### Backend compatibility

- No backend runtime code was changed during the frontend refactor.
- The initial contract comparison found response-shape and naming mismatches;
  see `FEATURE_SPEC.md`.

