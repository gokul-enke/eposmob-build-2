# QA rerun episode 13 — refund/payment reversal — 2026-08-02

## Result

Passed live through Marionette on the authorized testing account. The existing confirmed QA order `ORD-003968` was cancelled with payment method `CASH` and a SAR 2.00 refund amount. The Sales list changed to `CANCELLED`, and the order detail showed `CANCELLED` and `REFUNDED` with zero remaining balance.

No credentials, tokens, or personal contact data are included in this report.

## Recording

- Local MP4: `C:\Users\jim\.screencast-mcp\qa-video-rerun-20260802c\13-refund-payment-reversal.mp4`
- Screencast session: `rec-20260802-042904-486-javqx3`
- Target: `window:CLOUDPOS`
- Duration: 194.533 seconds
- Frame size: 2060x1192
- Codec: H.264
- Approximate frame rate: 6.297 fps
- Audio: none
- Size: 942,474 bytes
- Finalized gracefully: yes

## Media limitation

Marionette's live widget tree showed the final refund detail, but the native Windows capture surface remained visually stale on the earlier finalize modal even after an explicit CLOUDPOS window repaint. Sampled frames contain CLOUDPOS pixels only, but they do not visually prove the final refund state. The raw file remains private and was not uploaded to Cloudflare.

## Runtime notes

No new Flutter framework error was observed during this episode. The Marionette log endpoint continued to return a server error, so runtime verification is based on the live UI and the previously collected test/runtime evidence rather than a fresh log dump.

## Follow-up

Repeat this episode with a clean disposable completed-sale fixture after the Windows native capture/compositor issue is resolved, then approve the recording only if the final `CANCELLED`/`REFUNDED` detail is visible in sampled frames.
