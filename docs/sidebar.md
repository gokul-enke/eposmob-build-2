1. Billing Home
- `menu.home.main.access`

2. Dashboard
- `menu.dashboard.main.access`

3. Restaurant
- `menu.restaurant.main.access`

4. Attender
- `menu.restaurant.attender.access`

5. Kitchen Master
- `menu.restaurant.kitchen_master.access`

6. Sales (parent)
- `menu.sales.section.access`
- Sub-items:
- `menu.sales.orders.access`
- `menu.sales.confirmed_orders.access`
- `menu.sales.returns.access`
- `menu.sales.day_closing.access`
- `menu.sales.admin_day_records.access`

7. Category
- `menu.catalog.category.access`

8. Product (parent)
- `menu.catalog.product.section.access`
- Sub-items:
- `menu.catalog.product.list.access`
- `menu.catalog.product.stock.access`
- `menu.catalog.product.barcode.access`

9. Purchase (parent)
- `menu.purchase.section.access`
- Sub-items:
- `menu.purchase.orders.access`

10. Reports (parent)
- `menu.reports.section.access`
- Sub-items:
- `menu.reports.sales_executive.access`
- `menu.reports.executive_summary.access`
- `menu.reports.customer_transactions.access`
- `menu.reports.supplier_transactions.access`
- `menu.reports.non_stock.access`
- `menu.reports.consumed_stock.access`

11. Transactions (parent)
- `menu.transactions.section.access`
- Sub-items:
- `menu.transactions.invoice.access`
- `menu.transactions.receipts.access`
- `menu.transactions.customer_voucher.access`
- `menu.transactions.supplier_voucher_purchase.access`

12. Party Accounts (parent)
- `menu.party_accounts.section.access`
- Sub-items:
- `menu.party_accounts.customer_transactions.access`
- `menu.party_accounts.supplier_transactions.access`

13. Customers
- `menu.customers.main.access`

14. Suppliers (parent)
- `menu.suppliers.section.access`
- Sub-items:
- `menu.suppliers.list.access`
- `menu.suppliers.transactions.access`
- `menu.suppliers.voucher.access`

15. Printer
- `menu.settings.printer.access`

16. Settings
- `menu.settings.main.access`

17. Logout
- `menu.session.logout.access`

## Desktop and tablet layout behavior

- The explicit expand/collapse choice is saved locally as
  `navigation_sidebar_expanded` by `SharedPreferenceProvider`. New installations
  default to expanded. The choice survives page navigation, app restarts, user
  and store switches, ordinary logout, and clearing cached local data. A full
  API key reset clears it along with other layout settings.
- Expanded mode reserves 200 logical pixels; collapsed mode reserves 60.
  Hovering anywhere on the collapsed rail reveals the same full sidebar over
  the page, without changing the page width or recreating its state. Leaving
  the sidebar closes the preview immediately. Hovering never writes preferences.
- The toggle controls the saved choice. During a hover preview it expands and
  pins the sidebar; collapsing keeps it closed until the pointer leaves and
  re-enters the rail. Sidebar controls remain outside the billing Tab order.
- Touch input still uses the explicit toggle. Mobile retains its existing drawer.

## Utility controls present in sidebar

1. User Switcher widget
- `menu.utility.user_switcher.access`

2. Store Switcher widget 
- `menu.utility.store_switcher.access`

## Notes for backend handoff

1. Keep parent and sub-item keys independent so you can hide one sub-item without hiding others.
2. If you want current behavior parity, parent visibility can be computed as: show parent when any child key is granted.
