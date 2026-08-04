# CLOUDPOS QA Video Plan

Status: inventory complete; E00-E24 recorded; E03, E06-E07, and E09-E10 remain blocked at mutation or fixture gates, while the other recorded episodes need follow-up coverage.

The historical E00-E24 plan is retained for traceability. A user-authorized 11-episode mutation rerun was completed on 2026-08-02; its current results and remaining POST-form gaps are recorded in `QA_RERUN_20260802_REPORT.md`.

This plan turns the Flutter project into a reviewable QA video series. Each episode is a short, focused business workflow with a separate MP4, test report, expected result, actual result, runtime-error check, and—when requested—a temporary Cloudflare link.

## Inventory evidence

### Startup and navigation

The application bootstraps through `BaseUrlWrapper` and can route through:

1. API-key setup (`/api-key`) when the saved tenant/base URL requires it.
2. Sign-in (`/login`).
3. Store selection and bootstrap.
4. `MainScreen`, which hosts the permission-aware side menu and responsive content.

The primary Flutter entry point is `lib/main.dart`. The login flow is in `lib/screens/login/`, and the desktop shell is `lib/components/main_screen.dart`.

### Permission-aware side-menu modules

The side menu in `lib/widgets/side_menu.dart` contains these user-visible areas:

- Home and Billing
- Dashboard
- Restaurant and Store mode
- Attender and Kitchen Master
- Sales: Sales, Confirmed Orders, Sales Return, Day Sale Closing, Admin Day Sale records, Online Orders
- Quotations
- Category
- Product: Product, Stock, Product Barcode
- Purchase: Purchase Orders
- Reports: Sales Executive, Executive Summary, Customer Transactions, Supplier Transactions, Stock, Non-Stock, Consumed Stocks
- Transactions: Invoice, Receipts, Customer Voucher, Supplier Voucher, Proforma Invoice, Expense
- Party Accounts: Customer Transactions and Supplier Transactions
- Customers
- Suppliers: Suppliers, Supplier Transactions, Supplier Voucher
- Printer and Settings
- Logout

Menu visibility is permission-gated through `RoleProvider`. Important permission families include:

```text
menu.home.*
menu.dashboard.*
menu.restaurant.*
menu.sales.*
menu.quotation.*
menu.catalog.*
menu.purchase.*
menu.reports.*
menu.transactions.*
menu.party_accounts.*
menu.customers.*
menu.suppliers.*
menu.settings.*
billing.store.access
menu.utility.store_switcher.access
menu.utility.user_switcher.access
```

Role variants must be tested separately where they change visible menu items or allowed actions.

### Screen and feature inventory

| Area | Source evidence | Main QA concerns |
|---|---|---|
| Login and tenant setup | `lib/screens/login/` | API key, base URL, validation, login failure, session restore, logout |
| Home and dashboard | `lib/screens/home/`, `lib/screens/homenew/`, `lib/screens/dashboard/` | loading, KPIs, navigation, timeout, empty/error states |
| Counter billing | `lib/features/billing/`, `lib/screens/billing/` | product, price, stock, quantity, tax, customer, delivery, payment, checkout |
| Mobile billing | `lib/features/billing/presentation/widgets/mobile/` | tabs, sheets, rehydration, barcode, offline, responsive behavior |
| Restaurant billing | `lib/screens/billing/restaurant/`, `lib/screens/restaurant/` | tables, menu, modifiers, KOT, kitchen state, unpaid table orders |
| Catalog | `lib/screens/category/`, `lib/screens/product/` | create/edit/disable, variants, media, units, stock, barcode |
| Customers | `lib/screens/customers/`, `lib/screens/customer_profile/` | CRUD, selection, credit, history, loyalty, address, stale context |
| Sales lifecycle | `lib/screens/sales/`, `lib/screens/sales_return/`, `lib/screens/edit_order/` | save, resume, confirm, cancel, status, return, refund, day close |
| Quotations | `lib/screens/sales/quotations_list.dart` and related widgets | create, edit, checkout, conversion, totals |
| Purchasing | `lib/screens/purchase/`, `lib/screens/suppliers/` | purchase order, supplier, voucher, totals, stock effect |
| Transactions | `lib/screens/transactions/` | invoices, receipts, vouchers, proforma, expense, accounts, filters |
| Reports | `lib/screens/reports/` | filters, pagination, totals, empty states, export/print |
| Printing | `lib/screens/print/`, `lib/services/*print*` | printer settings, previews, receipt/KOT/barcode layouts, unavailable printer |
| Settings and integrations | `lib/screens/settings/`, `lib/services/` | offline data, realtime sync, WhatsApp, cash drawer, payment terminal |
| Profile/support/utility | profile, notifications, support, loyalty, kiosk screens | access, navigation, safe empty states |

### Services, providers, and risk-bearing integrations

Key services include `CheckoutService`, `PrintService`, `QuotationPrintService`, `CashDrawerService`, `DevelopmentPrinterService`, `PineLabsTerminalService`, `PrinterPermissionService`, `TenantDomainService`, and `SessionResetService`.

Important provider domains include authentication/roles, store session, billing/cart, products/stock, customers, suppliers/purchases, payments, reports, transactions, restaurant tables/menu/orders, offline sync, and realtime sync.

External or hardware-dependent paths must be marked as simulated, unavailable, or verified with the appropriate test device. Never claim a print, payment-terminal, cash-drawer, or backend sync path passed solely because a button was clickable.

### Existing automated QA evidence

There are 102 Dart test files under `test/`. Existing coverage includes:

- Billing desktop/mobile smoke, controllers, rehydration, keyboard order, payment validation, delivery, coupon, crash guards, offline behavior, and online-payment gates
- Cart safety, oversell confirmation, stock/variant scoping, sale units, barcode queues, and multi-unit pricing
- Order lifecycle, save/resume behavior, payment summaries, quotations, returns, refunds, and receipt customer balance
- Product/category/variant behavior and barcode layouts
- Customer widgets, filters, accessibility, responsive breakpoints, and performance helpers
- Purchase totals, stock reports, tenant domain behavior, printer service, and realtime sync

Automated tests are regression evidence. They do not replace live UI recording of permission gates, backend behavior, loading states, or real navigation.

The existing `PRODUCTION_QA_SCENARIOS.md` records prior live evidence and known risks. Recheck its findings from a clean session instead of assuming them to be current. In particular, it identifies pending live verification for invalid login/logout, non-cash payment methods, save/resume/print, returns, full catalog CRUD, reports, restaurant flows, and offline network toggling. It also records placeholder/backend-confirmation concerns in restaurant providers, customer chat, mobile coupons, company accounts, and print preview.

## Prioritized episode backlog

Episodes are intentionally separate. A happy-path episode should normally be 2–8 minutes; edge cases can be separate short episodes.

| ID | Filename | Episode | Priority | Mutation level | Status |
|---|---|---|---|---|---|
| E00 | `00-navigation-overview-sanitized.mp4` | Read-only app orientation and menu tour | P0 | None | Needs follow-up |
| E01 | `01-login-store-day-close-sanitized.mp4` | API key/base URL, login, store selection, sync, day-close prompt, logout | P0 | Low | Needs follow-up |
| E02 | `02-roles-permissions-switchers-sanitized.mp4` | Role-based menu visibility, store switcher, user switcher | P0 | Low | Needs follow-up |
| E03 | `03-basic-sale-payment-approved.mp4` | Add a safe test product, customer, cash payment, confirm, verify invoice | P0 | High | Blocked |
| E04 | `04-pricing-variants-stock-quantity.mp4` | Price selection, variants, stock lots, units, quantity limits, barcode sale | P0 | Medium | Needs follow-up |
| E05 | `05-customer-discount-coupon-delivery.mp4` | Customer CRUD/selection, discount, coupon, delivery method and charge | P1 | Medium | Needs follow-up |
| E06 | `06-payment-methods-checkout.mp4` | Cash/card/UPI/credit validation, exact paid amount, checkout state | P0 | High | Blocked |
| E07 | `07-saved-orders-edit-print.mp4` | Save draft, resume, edit, confirm, print/retry, duplicate-action guards | P1 | High | Blocked |
| E08 | `08-sales-orders-statuses.mp4` | Sales, confirmed orders, status changes, cancel, online orders | P1 | Medium | Needs follow-up |
| E09 | `09-returns-refunds-approved.mp4` | Find a completed sale, partial return, refund breakdown, stock effect | P0 | High | Blocked |
| E10 | `10-day-closing-final.mp4` | Open shift, day-sale closing, admin day records, pending-day behavior | P0 | High | Blocked |
| E11 | `11-quotations-final.mp4` | Create, edit, list, inspect, and convert a quotation | P1 | Medium | Needs follow-up |
| E12 | `12-categories-approved.mp4` | Create, edit, validation, disable, and list categories | P1 | Medium | Needs follow-up |
| E13 | 13-products-variants-media-approved.mp4 | Product list/detail, properties, variants, images/video, sellability | P1 | Medium | Needs follow-up |
| E14 | 14-stock-and-barcodes-approved.mp4 | Stock detail, adjustment, transfer, withdrawal, barcode filters, layout/print flow | P1 | Medium | Needs follow-up |
| E15 | 15-customers-profiles-credit-approved.mp4 | Customer list/profiles, credit limits, balances, transactions | P1 | High | Needs follow-up |
| E16 | 16-purchases-suppliers-approved.mp4 | Supplier CRUD, purchase order, purchase entry, voucher, stock update | P1 | High | Needs follow-up |
| E17 | `17-transactions-approved.mp4` | Invoice, receipts, customer/supplier vouchers, proforma, expenses, accounts | P1 | High | Needs follow-up |
| E18 | `18-reports-approved.mp4` | Sales, executive, customer, supplier, stock, non-stock, consumed reports | P1 | None | Needs follow-up |
| E19 | `19-restaurant-attender-kitchen-approved.mp4` | Tables, menu, modifiers, attender, KOT, kitchen status, unpaid table order | P1 | High | Needs follow-up |
| E20 | `20-settings-integrations-approved.mp4` | Settings, printer, barcode layout, cash drawer, WhatsApp, payment terminal | P2 | Medium | Needs follow-up |
| E21 | `21-offline-realtime-sync-approved.mp4` | Offline mutation, reconnect, retry, deduplication, realtime sync state | P0 | High | Needs follow-up |
| E22 | `22-dashboard-home-utility-approved.mp4` | Home, dashboard, notifications, profile, support, loyalty, kiosk/legal pages | P2 | None | Needs follow-up |
| E23 | `23-negative-validation-recovery-approved.mp4` | Invalid input, failed login, insufficient stock, failed payment, timeout, retry | P0 | Low | Needs follow-up |
| E24 | `24-responsive-keyboard-accessibility-approved.mp4` | Desktop/mobile layouts, focus order, keyboard, accessibility, empty states | P1 | Low | Needs follow-up |

## Episode execution rules

1. Use a non-production store and permissioned QA account.
2. Confirm safe test data before any financial or inventory mutation.
3. Start Screencast MCP before the first UI action and capture only the app window.
4. Record the happy path and edge case separately when the flow is long.
5. Verify business results in a list/report, not only a success toast.
6. Check runtime errors after each episode.
7. Gracefully stop and verify every MP4 with media info and sampled frames.
8. Share only sanitized videos. A Quick Tunnel link is public to anyone who has it and lasts only while the local server/tunnel runs.
9. Update the index immediately after each episode, including blocked reasons and defects.

## Required test-data matrix

Before mutation-heavy episodes, identify:

- Non-production store and QA role accounts
- Walk-in customer and a named customer eligible for credit
- Sellable product with multiple stock lots, variant, unit, and barcode
- Completed sale suitable for partial return
- Test cash, card, UPI, and credit payment configuration
- Supplier and purchase-order test data
- Restaurant tables/menu/modifier/KOT data, if backend-supported
- Printer/cash-drawer/terminal simulation or explicit unavailable status
- Ability to test offline/reconnect without risking duplicate production orders

If these prerequisites are missing, complete read-only episodes and mark the dependent episode blocked rather than guessing.

## Deliverables

For each episode create:

- MP4 recording under the recording directory
- `qa-video-reports/E##-<slug>.md` with purpose, preconditions, steps, expected/actual result, defects, runtime errors, media info, and links
- Updated `QA_VIDEO_INDEX.md`
