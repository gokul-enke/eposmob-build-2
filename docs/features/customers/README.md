# Customers Feature

This directory is the shared human-readable reference for the Customers feature.

## Documents

- `FEATURE_SPEC.md` — frontend UI, UX, formatting, keyboard, and business rules.
- `TODO.md` — technical work waiting for backend/frontend coordination.
- `CHANGELOG.md` — coordinated frontend/backend changes and compatibility notes.
- `contracts/openapi/customers.yaml` — synchronized machine-readable backend API
  contract.

## Ownership

| Area | Source of truth |
|---|---|
| Endpoint, request, response, validation | Backend OpenAPI contract |
| Table columns, filters, colors, keyboard behavior | `FEATURE_SPEC.md` |
| Flutter implementation | `lib/features/customers/` and `lib/screens/customers/` |
| Open technical work | `TODO.md` and linked Jira tickets |
| Change history | `CHANGELOG.md` |

## Relevant frontend files

- `lib/screens/customers/customers.dart`
- `lib/features/customers/presentation/widgets/customer_page_header.dart`
- `lib/features/customers/presentation/widgets/customer_filter_panel.dart`
- `lib/features/customers/presentation/widgets/customer_desktop_table.dart`
- `lib/features/customers/presentation/widgets/customer_card_list.dart`
- `lib/providers/customer_provider.dart`
- `lib/models/customer_list.dart`

## Contract synchronization

Run:

```bash
./scripts/sync-customer-contract.sh
```

The frontend copy should never be manually edited.
