# Synchronized API Contracts

Files under `contracts/openapi/` are synchronized from the backend repository.
They are references for frontend development and must not be edited manually.

The backend remains the source of truth.

To synchronize the Customer contract:

```bash
./scripts/sync-customer-contract.sh
```

To check whether the frontend copy is current without modifying it:

```bash
./scripts/sync-customer-contract.sh --check
```

