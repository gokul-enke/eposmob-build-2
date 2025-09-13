# Billing Page Reusable Logic - Developer Reference

## Core State Management
1. **Internet Connectivity** - Real-time connection monitoring with status indicator
2. **Loading States** - Individual loading flags for each operation (clearCart, saveOrder, confirmOrder, etc.)
3. **Form State Management** - Controllers for all input fields with proper disposal
4. **Focus Management** - Focus nodes for keyboard navigation and field selection
5. **Debounce Logic** - Timer-based input debouncing for search and barcode processing

## Customer Management
6. **Customer Autocomplete** - Search by phone/name with keyboard navigation
7. **Customer Selection** - Manual vs automatic customer assignment logic
8. **Customer Balance Display** - Show customer credit/debit with color coding
9. **Customer Validation** - Phone number validation and customer existence checks
10. **Sales Executive Integration** - Auto-assign default customer based on current sales executive
11. **Add New Customer** - Modal integration with auto-selection after creation

## Cart Operations
12. **Add to Cart Logic** - Product selection with stock management and pricing
13. **Remove from Cart** - Individual item removal with confirmation
14. **Quantity Control** - Increment/decrement with validation
15. **Price Editing** - Custom price and MRP modification per item
16. **Cart Validation** - Ensure valid pricing before operations
17. **Cart Clear** - Complete cart reset with state cleanup

## Product Management
18. **Barcode Processing** - Weight-based (KG) and count-based (PC) product scanning
19. **Product Autocomplete** - Search and select products with stock variants
20. **Stock Management** - Handle products with/without stock tracking
21. **Product Validation** - Ensure selected product exists and has valid data

## Payment Processing
22. **Multi-Payment Methods** - Cash, Card, UPI, Debit with individual amounts
23. **Payment Validation** - Ensure payment methods are selected before confirmation
24. **Balance Calculation** - Complex logic for customer credit and cash balance
25. **To Customer Credit Toggle** - Handle excess payment allocation
26. **Payment Method Modal** - Centralized payment selection interface

## Order Management
27. **Save Order** - Local storage with customer and payment data
28. **Load Order for Editing** - Rehydrate UI state from saved orders
29. **Confirm Order** - API integration with validation and error handling
30. **Order State Rehydration** - Restore complete UI state when editing orders
31. **Order Printing** - Generate print-ready order data

## Delivery & Logistics
32. **Delivery Method Selection** - Store pickup, car delivery, door delivery
33. **Delivery Date/Time** - Schedule future deliveries
34. **Car Number Validation** - Required for car delivery method
35. **Comment System** - Order notes and special instructions

## Discount & Coupon System
36. **Coupon Application** - API-based coupon validation and discount calculation
37. **Manual Discount** - Flat amount and percentage discounts
38. **Discount Validation** - Ensure valid discount amounts
39. **Price Summary Calculation** - Net total, discount, tax calculations

## UI Components
40. **Sidebar Management** - Collapsible product/order sidebar
41. **Tab Navigation** - Switch between products and saved orders
42. **Quick Access Icons** - Payment, delivery, discount shortcuts
43. **Action Buttons** - Clear, save, confirm with loading states
44. **Cart Table** - Responsive item display with inline editing
45. **Payment Summary** - Compact and full view modes

## Validation Logic
46. **Form Validation** - Required fields and business rule enforcement
47. **Internet Dependency** - Disable online features when offline
48. **Customer Requirement** - Ensure customer selected before order operations
49. **Cart Requirement** - Ensure items in cart before operations
50. **Payment Requirement** - Validate payment methods for online orders

## API Integration
51. **Order Creation API** - Multi-payment support with discount data
52. **Customer Search API** - Phone and name-based customer lookup
53. **Coupon Validation API** - Real-time coupon verification
54. **Cart Sync API** - Synchronize cart with server state
55. **Order Details API** - Fetch order data for printing

## Local Storage
56. **Saved Orders** - Local order persistence with editing capability
57. **Order Rehydration** - Restore orders across app sessions
58. **Confirmed Orders** - Move orders between saved and confirmed states
59. **Order Deletion** - Remove orders from local storage

## Keyboard & Input
60. **Keyboard Shortcuts** - F6-F9 function key support
61. **Virtual Keyboard Integration** - Custom keyboard for numeric inputs
62. **Barcode Stream Processing** - Real-time barcode scanning
63. **Auto-focus Management** - Proper field focusing after operations

## Settings Integration
64. **App Settings Provider** - Feature toggles (barcode sales, discounts, etc.)
65. **Currency Display** - Dynamic currency formatting
66. **Price Rounding** - Optional price rounding based on settings
67. **Auto-assign Customer** - Configurable default customer assignment

## Error Handling
68. **API Error Management** - Graceful error handling with user feedback
69. **Validation Error Display** - Clear error messages for invalid operations
70. **Network Error Handling** - Offline mode with appropriate messaging
71. **Exception Catching** - Comprehensive try-catch blocks

## Provider Pattern Integration
72. **LocalProductProvider** - Cart and product state management
73. **CustomerSelectionProvider** - Global customer state
74. **CartProvider** - API cart operations
75. **AuthModel** - Authentication and user context
76. **AppSettingsProvider** - Application configuration
77. **KeyboardProvider** - Virtual keyboard state
78. **DeliveryMethodsProvider** - Delivery options management

## Utility Functions
79. **Amount Formatting** - Consistent currency display
80. **Date/Time Handling** - Delivery scheduling utilities
81. **JSON Serialization** - Multi-payment data encoding
82. **State Cleanup** - Proper resource disposal and state reset
83. **Debug Logging** - Comprehensive logging for troubleshooting

## Future Provider Structure Suggestions
- **BillingProvider** - Centralize all billing logic
- **PaymentProvider** - Handle payment processing
- **OrderProvider** - Manage order lifecycle
- **ValidationProvider** - Business rule validation
- **UIStateProvider** - UI state management