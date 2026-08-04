# E22 — Dashboard, Home, and Utility Surfaces

Status: Needs follow-up

## Scope

Read-only coverage of Home, Dashboard, the profile/user switcher dropdown, and the dashboard period filter. Source inventory also checked the desktop side menu for notification, support, loyalty, kiosk, and legal destinations.

## Recording

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\22-dashboard-home-utility-approved.mp4`
- Raw source: retained locally and not shared
- Capture: CLOUDPOS application window only; 2560×1440; H.264; no audio
- Duration: 155.4 seconds
- Sanitization: account/profile area, user-switcher content, home product/order panel, dashboard account name, and dashboard metric values were redacted; UI labels and navigation remain visible
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E22-dashboard-home-utility-approved\`

## Observations

- Home exposes the billing workspace, empty saved-order state, product/order tabs, cart summary, and keyboard-labelled actions.
- Dashboard exposes Sales Overview, Company Account Overview, Your Account Overview, Sales Performance, refresh/date controls, and a Month period selector.
- The period selector offered Today, Week, Month, and Year. Today was selected and the dashboard remained usable; no business data was changed.
- The profile dropdown exposes Switch User and available user entries. No user switch or logout was performed.
- The desktop side-menu source contains no separate user-visible notification, support, loyalty, kiosk, privacy, or terms/legal page in this build; those remain unverified or unavailable from the current route surface.

## Edge case / blocker

Profile switching, logout, dashboard refresh against live data, and any unavailable utility destinations require explicit authorization or a separate route/build. No account, permission, or business-data mutation was attempted.

## Runtime errors

The known P2 Flutter ListTile assertion reproduced while the profile/user-switcher dropdown was visible: `user_switcher.dart:464` warns that a decorated ListTile can hide its background/ink splash. No new P1 navigation or data error was isolated.

## Result

Home, Dashboard, period selection, and user-switcher entry points are captured safely. Notification/support/loyalty/kiosk/legal coverage is not exposed in the desktop build and needs route confirmation or a separate build.
