# E02 - Roles, permissions, and switchers

Status: Needs follow-up

## Scope

Read-only inspection of the signed-in profile menu and the available user-switcher entries. No user was switched, no store was changed, and no business data was modified.

## Recorded steps and results

1. Opened the signed-in profile menu.
2. Inspected the visible "Switch User" action and the available user entries.
3. Confirmed the current user selection indicator.
4. Closed the menu and returned to the Billing shell.
5. Inspected the side-menu permission surface and the "Other" section.

Expected: profile switching is discoverable, the current user is clearly indicated, and permission-gated menu items are stable.

Actual: the switch-user menu displayed multiple available accounts and a selected indicator. A second role/permission account and a store-switch action were not available for a safe read-only comparison, so permission denial and store-switch behavior remain unverified.

## Defects and runtime errors

- P2 Flutter assertion: "ListTile background color or ink splashes may be invisible" from lib/widgets/user_switcher.dart:464. The diagnostic recommends giving the ListTile its own Material ancestor or removing the intermediate DecoratedBox background.
- No navigation failure or business-data mutation was observed.

## Media verification

- Approved video: C:\Users\jim\.screencast-mcp\recordings\02-roles-permissions-switchers-sanitized.mp4
- Duration: 75.6 seconds
- Frame: 2560x1440
- Frame rate: 14.367 fps
- Video: H.264; audio: none
- Size: 871,798 bytes
- Sample frames: C:\Users\jim\.screencast-mcp\frames\E02-roles-permissions-switchers-sanitized\
- Profile/sidebar identity data was covered during the switcher view; raw video is not approved for sharing.

## Sharing

Cloudflare link: Pending.
