# E21 — Offline and Realtime Sync

Status: Needs follow-up

## Scope

Read-only coverage of Offline Data, Realtime Sync Tester, and the Offline Mode setting. The pass inspected cache domains, sync/clear entry points, connection controls, and the safe toggle/restore behavior without syncing, clearing, connecting, disconnecting the network, or changing business data.

## Recording

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\21-offline-realtime-sync-approved.mp4`
- Raw source: retained locally and not shared
- Capture: CLOUDPOS application window only; 2560×1440; H.264; no audio
- Duration: 119.2 seconds
- Sanitization: profile/sidebar region and the main application region were redacted before sharing; the Realtime Sync Tester contains sensitive prefilled configuration, so no raw tester frame is shared
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E21-offline-realtime-sync-approved\`

## Observations

- Offline Data presents catalog/inventory, billing/checkout, and customers/suppliers cache groups with per-row Sync and Clear controls plus a Sync All entry point.
- The page reports cached-data state and aggregate counts without requiring a mutation for inspection.
- Realtime Sync Tester visibly exposes disconnected status, secure-WebSocket and auto-pull controls, connection actions, latest-result state, and a warning that testing performs real auth/sync-related requests.
- Offline Mode changed from live internet status to manually enabled and was restored to live internet status during the same pass.

## Edge case / blocker

Sync/Clear/Sync All, Realtime Tester Connect, network interruption/reconnect, retry/deduplication, and actual offline billing require an authorized disposable environment and explicit approval because they affect local cache, authentication, or backend synchronization state. Those actions were intentionally not executed.

## Runtime errors

The runtime buffer was cleared before E21. No new Flutter runtime error was found after the recorded actions.

## Result

The user-visible offline and realtime-sync controls are documented and safely captured. Mutation, reconnect, and deduplication coverage remains pending the required safe fixture and authorization.
