# E01 - Login, store selection, sync, and day-close prompt

Status: Needs follow-up

## Scope

Recorded the non-destructive login and store-bootstrap flow, including the pending prior-day prompt. The "No" option was selected, so no day close and no financial transaction were created.

## Preconditions

- CLOUDPOS was running as a Windows Flutter debug build.
- Marionette was connected to the Flutter VM Service.
- Screencast MCP targeted only the visible `CLOUDPOS` application window.
- A prefilled QA account and the available store list were used; credentials are intentionally omitted.

## Recorded steps and results

1. Inspected the login semantics tree without exposing credentials.
2. Submitted the prefilled QA login.
3. Confirmed the store-selection screen and selected the available store.
4. Continued and waited for product-catalog bootstrap/sync.
5. Confirmed the "Day Close Pending" prompt for the previous sales day.
6. Selected "No" to defer closing the previous day.
7. Verified the Billing screen, product tiles, order controls, and zero-value cart.

Expected: the user can authenticate, choose a store, wait for initial sync, defer an outstanding day close, and reach Billing without creating business data.

Actual: all steps reached the expected UI state. The video capture required a harmless real-window focus input after Marionette state transitions because the first window-capture attempts retained a stale login frame. The accepted recording contains the visible transitions and was finalized gracefully.

## Defects and runtime errors

- P1 follow-up: Flutter reported `setState() called after dispose(): BillingPageState` while `AppSettingsProvider` notified listeners during store bootstrap. Stack locations include `billing_page.dart:9772`, `billing_page.dart:322`, `billing_page.dart:451`, `app_settings_provider.dart:59`, `store_session_provider.dart:146`, and `store_selection_screen.dart:384`.
- The same event also reported use of a defunct `BillingPageState` context from `_syncStockEnabledSetting`.
- These are lifecycle/mounted-guard or cancellation defects; repeat after leaving Billing or changing stores and verify that async listeners/timers are cancelled.

## Media verification

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\01-login-store-day-close-sanitized.mp4`
- Duration: 136.2 seconds
- Frame: 2560x1440
- Frame rate: 13.62 fps (encoded variable rate)
- Video: H.264; audio: none
- Size: 883,378 bytes
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E01-login-store-day-close-sanitized\`
- Login fields were covered with an irreversible black redaction during the login interval. The raw recording is not approved for sharing.

## Sharing

Cloudflare link: Pending. Publish only the sanitized file from a dedicated, allow-listed QA-video share directory.
