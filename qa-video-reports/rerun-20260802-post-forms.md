# Supplemental POST-form QA episode — 2026-08-02

## Scope

Authorized testing-account coverage for saved orders and standalone customer-voucher, supplier-voucher, and expense forms. Synthetic QA values only; no credentials, tokens, phone numbers, or real delivery data are recorded in this report.

## Result

Passed functionally:

- Saved a disposable billing order, opened its printer-selection route without sending a physical print, and resumed the order into the cart.
- Created customer voucher `1000489` for Test Default, type `other`, paid SAR 1.00; list and detail verified the item `QA-CUSTOMER-VOUCHER-20260802`.
- Created supplier voucher `SVCH-1000307` for Supplier 1FUNZCART, type `other`, paid SAR 1.00; list and detail verified the item `QA-SUPPLIER-VOUCHER-20260802`.
- Created expense `EXP00106` with description `QA-EXPENSE-20260802`, SAR 1.00, Transportation category, Indirect Expense Account debit, Cash Account credit, and status `SUCC`; list and detail verified.

Refund-specific payment reversal was not exposed as a separate action in the tested route and remains a follow-up fixture.

## Recording evidence

- Local MP4: `C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\12-remaining-post-forms-final.mp4`
- Session: `rec-20260802-034823-346-00alkq`
- Target requested: `window:CLOUDPOS`
- Duration: 980.8 seconds
- Media: 1920×1080, H.264, approximately 14.778 fps, no audio, 15,502,330 bytes
- Finalized gracefully: yes
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\rerun-20260802c-12-postforms-final\`

The native Windows compositor sampled unrelated desktop/browser content in all sampled frames. The raw recording is private, was not uploaded, and has no Cloudflare link.

## Runtime notes

No Flutter framework error stopped these flows. The Marionette log retrieval endpoint returned a server error during final collection, so the runtime conclusion is based on the live UI completion and the earlier clean focused/full test runs. Driver-only interaction retries did not stop the episode.
