# E19 — Restaurant, Attender, and Kitchen

Status: Needs follow-up

## Scope

Read-only coverage of Restaurant billing, the Attender role-specific restaurant page, and Kitchen Master. The pass inspected table/order selection, menu/product cards, cart states, disabled empty-order controls, and kitchen status lanes without selecting a table, adding a product, creating a KOT, confirming an order, or changing a kitchen status.

## Recording

- Approved video: `C:\Users\jim\.screencast-mcp\recordings\19-restaurant-attender-kitchen-approved.mp4`
- Raw source: retained locally and not shared
- Capture: CLOUDPOS application window only; 2560×1440; H.264; no audio
- Duration: 164.3 seconds
- Sanitization: profile/sidebar region and the main content region were redacted before sharing
- Sample frames: `C:\Users\jim\.screencast-mcp\frames\E19-restaurant-attender-kitchen-approved\`

## Observations

- Restaurant page exposes order/menu/table context, product cards, cart tabs, saved/ongoing order tabs, and disabled empty-order actions.
- Attender routes to the role-specific RestaurantPage variant and exposes the same order/menu surface with counter billing disabled by configuration.
- Kitchen Master exposes Pending, Preparing, and Ready lanes, populated order cards, item status text, and completed-order visibility.
- The empty-order state prevents KOT + BILL and confirm actions until an order is selected.

## Defect

Entering the Restaurant/Attender surface reproduced a P1 Flutter assertion: `CustomerSelectionProvider.setSelectedCustomer()` notifies listeners during build while `OrderPanelState` hydrates its default customer from `restaurant_page.dart` / `order_panel.dart`. The page remained usable for read-only inspection, but the initialization path should be fixed and re-tested.

## Edge case / blocker

Order creation, table assignment, modifiers, KOT printing, confirm/bill, kitchen status transitions, and unpaid-table behavior require a disposable restaurant fixture and explicit mutation/printing authorization.

## Runtime errors

- P1: CustomerSelectionProvider `setState() or markNeedsBuild() called during build` during Restaurant/Attender initialization.
- No separate Kitchen Master assertion was isolated after the route loaded.
