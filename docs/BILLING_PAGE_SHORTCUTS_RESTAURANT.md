# Billing Page Keyboard Shortcuts (Restaurant)

File scope: `lib/screens/billing/billing_page_restaurant.dart`

## Global

- `Ctrl + H`: Open keyboard shortcuts help dialog (restaurant mode)
- `Ctrl + K`: Toggle virtual keyboard
- `Ctrl + D`: Focus cart list in right sidebar
- `D`: Open cash drawer
- `Ctrl + A`: Focus category row and highlight `ALL`
- `Ctrl + S`: Focus search product field

## Cart

These work when cart list focus is active.

- `Arrow Up / Arrow Down`: Move focused cart row
- `Enter` or `Q`: Open quantity edit dialog
- `+ / -`: Increase or decrease focused item quantity
- `P`: Open price edit dialog
- `M`: Open MRP edit dialog
- `T`: Open tax-rate edit dialog
- `I`: Open item details dialog
- `Delete`: Remove focused cart row

## Billing

- `F1`: Clear cart
- `F2`: Open checkout confirm
- `F3`: Open checkout at Customer step
- `F4`: Open checkout at Delivery step
- `F5`: Open checkout at Payment step
- `F6`: Open checkout confirm and print
- `F7`: Create new order
- `F8`: Open checkout save mode
- `F9`: Open checkout save and print mode
- `F10`: Open checkout at Discount step
- `F12`: Toggle sidebar/cart-orders keyboard context

## Navigation

- Expected keyboard path:
1. `Ctrl + A` -> category row (focus starts at `ALL`)
2. `Arrow Left / Right` -> move across categories
3. `Tab` -> search field
4. Type search text
5. `Tab` -> product grid
6. `Arrow Keys` -> move across products
7. `Enter` or `Space` -> add focused product to cart
8. `Tab` -> cart list (first item focused)
- `Shift + Tab`: move backward across the same sections

## Checkout Modal

Applies to quantity/price/mrp/tax dialogs opened from cart:

- `Enter` in input field: submit/save
- `Tab`: move focus to action buttons
- Focused `Save` button: orange rounded focus outline
- Focused `Cancel` button: orange rounded focus outline
