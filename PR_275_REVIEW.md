# PR #275 Review

Status: **Changes requested — not merged**

## Major issues

- The ZATCA failed-invoice alert bypasses the invoice permission check, exposing invoice data and navigation to restricted users.
- Invalid API responses can be interpreted as zero failures, hiding a real compliance warning.
- A missing active store can trigger a tenant-wide invoice count.
- Older overlapping requests can overwrite newer ZATCA counts.
- `packing_photo_paths` is parsed but not displayed.
- String-encoded saved addresses are ignored in Shipping Details.
- A failed filtered invoice request can leave stale invoices visible under the “FAILED” filter.

## Verification

- The PR’s 19 new tests passed.
- No CI checks are configured.
- The PR should be merged only after the issues above are fixed and retested.
