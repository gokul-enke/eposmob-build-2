# Customers Feature TODO

This file records technical work discovered while comparing the Flutter Customer
module with the backend implementation.

Jira or another project-management system remains the source of truth for
assignment, discussion, deadlines, and delivery status. Add the Jira ticket ID
here after creating it.

## Status values

- `Open`
- `In Progress`
- `Blocked`
- `Ready for Review`
- `Done`
- `Cancelled`

## Priority values

- `P0` — blocks correct Customer functionality
- `P1` — important correctness or scalability work
- `P2` — maintainability or contract cleanup
- `P3` — optional improvement

## Open work

| ID | Priority | Area | Owner | Task | Jira | Status |
|---|---|---|---|---|---|---|
| CUST-001 | P0 | Backend API | Backend | Include customer `id` in every `customer-searchbar` result item. | — | Open |
| CUST-002 | P1 | API contract | Backend | Return canonical `customer_type`; temporarily retain `customerType` if older clients require compatibility. | — | Open |
| CUST-003 | P0 | API contract | Both | Align the paginated `customer-searchbar` response with the Flutter parser. | — | Open |
| CUST-004 | P1 | Scalability | Both | Replace frontend load-all/local pagination with backend filtering and pagination. | — | Open |
| CUST-005 | P1 | Backend API | Backend | Resolve Flutter `per_page=1000` versus backend maximum `100`. | — | Open |
| CUST-006 | P2 | Backend API | Backend | Apply `filter_alt_phone` independently or remove it from the documented contract. | — | Open |
| CUST-007 | P2 | Backend API | Backend | Implement and document `sort_asc`, or remove the unused option. | — | Open |
| CUST-008 | P1 | Backend tests | Backend | Add response-contract tests for customer search fields, pagination, filters, and error behavior. | — | Open |
| CUST-009 | P1 | Frontend tests | Frontend | Add JSON parsing tests after the backend response contract is finalized. | — | Blocked |
| CUST-010 | P2 | API consistency | Both | Standardize success, empty-result, validation, unauthorized, and server-error response shapes. | — | Open |
| CUST-011 | P2 | Frontend architecture | Frontend | Separate customer API, cache, repository, list state, and profile state from `CustomerProvider`. | — | Blocked |
| CUST-012 | P2 | Frontend models | Frontend | Split the large customer model into customer, address, transaction, order, and response models. | — | Blocked |
| CUST-013 | P2 | Customer profile | Frontend | Refactor profile information, addresses, orders, transactions, and loyalty as a separate feature slice. | — | Blocked |

## Blocking notes

- `CUST-009` is blocked until the backend search response is finalized.
- `CUST-011` through `CUST-013` are intentionally postponed while the Customer
  list contract is unstable.
- No frontend parser or pagination changes should be made merely to guess the
  future backend response.

## Completion workflow

When completing an API-related task:

1. Update the backend OpenAPI contract.
2. Synchronize the frontend contract:

   ```bash
   ./scripts/sync-customer-contract.sh
   ```

3. Add or update backend and frontend tests.
4. Update `FEATURE_SPEC.md` to describe the implemented behavior.
5. Add the completed work to `CHANGELOG.md`.
6. Update this task's Jira reference and status.

