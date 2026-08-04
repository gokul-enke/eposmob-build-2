# E20 — Settings, Printers, and Integrations

Status: Needs follow-up

## Scope

Read-only coverage of Settings and Printer Settings. The pass inspected company/language/offline/sync cards, screen orientation and developer-mode indicators, local-cache controls, printer roles, paper size, receipt themes, available printer devices, and safe action entry points without changing preferences, clearing cache, scanning/selecting a printer, or printing.

## Recording

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\20-settings-integrations-approved.mp4`
- Raw source: retained locally and not shared
- Capture: CLOUDPOS application window only; 2560×1440; H.264; no audio
- Duration: 131.7 seconds
- Sanitization: profile/sidebar region and the main settings/printer region were redacted before sharing
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E20-settings-integrations-approved\`

## Observations

- Settings exposes Company Info, Language, Offline Data, Last Product Sync, Resync Products, Realtime Sync Tester, Offline Mode, Notification Position, Screen Orientation, Developer Mode, Clear Local Storage, and Clear Product Cache entry points.
- Printer Settings exposes Billing, Quotation, Kitchen, and Barcode printer contexts; B2C/B2B tabs; paper size and receipt theme selectors; test/resync/clear actions; and two locally detected printer devices.
- No setting, printer selection, cache, sync, or print mutation was attempted.

## Edge case / blocker

Printer selection/test print, document resync, offline toggle behavior, cache clearing, and integration-specific settings require an authorized disposable environment and explicit permission because they affect local/device state.

## Runtime errors

No new Flutter runtime error was isolated during E20. The pre-existing CustomerSelectionProvider build-phase error remains in the active error buffer from the previous restaurant route.
