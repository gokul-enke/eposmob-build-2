/// Centralized [NumericFocusOrder] values used across the Billing flow.
///
/// Tab traversal is organized into bands so future widgets can be inserted
/// without colliding with existing values:
///
///   • Billing Page main scaffold
///       Header toolbar  → excluded from tab traversal (ExcludeFocus)
///       Entry row       → 10 .. 60   (existing convention)
///       Cart table      → 100         (single tab stop, internal arrow nav)
///       Action buttons  → 200 .. 240
///
///   • Sidebar (when activated via F12)
///       Tab switcher    → 100
///       Inner content   → 200 .. 500
///
///   • Checkout modal (per step, each in its own FocusTraversalGroup)
///       Inputs          → 100 .. 800
///       Footer          → 9000  (always traversed last in step)
///
///   • Standalone modals (Add Customer, Add Product, Delivery Method, etc.)
///       Use the same 100-band convention; footer at 9000.
///
/// Numeric gaps are intentional. Prefer 10-step gaps inside a band so that
/// new fields can be added without re-numbering siblings.
library;

/// Orders for the main Billing Page entry row, cart, and action buttons.
class BillingFocusOrders {
  BillingFocusOrders._();

  // --- Entry row (top of main panel) ---
  /// Barcode input (visible when `appSettings.barcodeSales == true`).
  static const double barcode = 10;

  /// Search Product autocomplete (visible when barcode mode is off).
  static const double searchProduct = 20;

  /// Quantity field.
  static const double quantity = 30;

  /// Unit price field.
  static const double unitPrice = 40;

  /// Add Item button (green +).
  static const double addItem = 50;

  /// Clear current entry (red X) button.
  static const double clearEntry = 60;

  // --- Cart table ---
  /// Single tab stop wrapping the whole cart table. Inside the cart, navigation
  /// is handled by arrow keys / Enter / Delete / +/- inside
  /// `_handleCartTableKey`. Inner cell widgets opt out of traversal via
  /// `Focus(skipTraversal: true)` to avoid creating dozens of tab stops.
  static const double cartTable = 100;

  // --- Action buttons (footer of main panel) ---
  static const double clearCart = 200;
  static const double saveOrder = 210;
  static const double confirmAndPrint = 220;
  static const double confirmOrder = 230;
  static const double saveAndPrint = 240;
}

/// Orders for the right-side keyboard-activatable Sidebar (Products / Orders).
class SidebarFocusOrders {
  SidebarFocusOrders._();

  /// Tab switcher (Products / Orders headers).
  static const double tabSwitcher = 100;

  // Products tab.
  static const double categorySearch = 200;
  static const double categoryGrid = 250;
  static const double productSearch = 300;
  static const double productGrid = 350;

  // Orders tab.
  static const double newOrderButton = 400;
  static const double savedOrdersGrid = 450;
  static const double quickAccessGrid = 500;
}

/// Orders for the Customer step inside `CheckoutModal`.
class CheckoutCustomerOrders {
  CheckoutCustomerOrders._();

  static const double searchField = 100;
  static const double selectedCard = 200;
  static const double customerList = 300;
  static const double addCustomerButton = 400;

  /// Footer (Confirm / Print / Save buttons) — always last in this group.
  static const double footer = 9000;
}

/// Orders for the Delivery step inside `CheckoutModal`.
///
/// `methodTilesBase` is the starting order for the dynamic delivery-method
/// tiles. Each tile receives `methodTilesBase + index`, so up to 90 tiles can
/// safely be rendered before colliding with `carNumber`.
class CheckoutDeliveryOrders {
  CheckoutDeliveryOrders._();

  static const double methodTilesBase = 100;
  static const double carNumber = 200;
  static const double comment = 300;
  static const double address = 400;
  static const double date = 500;
  static const double time = 600;

  static const double footer = 9000;
}

/// Orders for the Discount step inside `CheckoutModal`.
class CheckoutDiscountOrders {
  CheckoutDiscountOrders._();

  static const double flatDiscount = 100;
  static const double percentageDiscount = 200;
  static const double couponDropdown = 300;
  static const double skipButton = 400;
  static const double clearButton = 500;
  static const double applyButton = 600;

  static const double footer = 9000;
}

/// Orders for the Payment step inside `CheckoutModal` and the standalone
/// `PaymentMethodModal`.
///
/// Each payment method gets a row order and an amount order so the user can
/// Tab from the row (Space toggles) directly into its amount field.
class CheckoutPaymentOrders {
  CheckoutPaymentOrders._();

  static const double cashRow = 100;
  static const double cashAmount = 110;

  static const double cardRow = 200;
  static const double cardAmount = 210;

  static const double upiRow = 300;
  static const double upiAmount = 310;

  static const double codRow = 400;
  static const double codAmount = 410;

  static const double creditRow = 500;
  static const double toCustomerCreditToggle = 600;
  static const double transactionNumber = 700;

  static const double footer = 9000;
}

/// Orders for the standalone `AddProductWithBarcodeModal`.
class AddProductFocusOrders {
  AddProductFocusOrders._();

  static const double productName = 100;
  static const double purchasePrice = 200;
  static const double mrp = 300;
  static const double sellingPrice = 400;
  static const double quantity = 500;
  static const double itemCode = 600;
  static const double barcodeField = 700;
  static const double unitDropdown = 800;
  static const double categoryDropdown = 900;

  /// Sale-unit rows are dynamic; allocate from this base.
  static const double saleUnitRowsBase = 1000;

  static const double footer = 9000;
}
