# Keyboard Navigation & Focus Glow Guide

This document explains the architecture, design patterns, and setup details of the keyboard navigation (Tabbing, Arrow keys, Enter/Space actions) and visual focus glow highlights across the codebase.

---

## 1. Overview of Flutter's Focus System

Flutter uses a hierarchical focus tree to manage which widget receives keyboard inputs. Key points:
* **FocusNode:** An object that represents the focus state of a widget. It is attached to the widget tree.
* **FocusScope:** Groups focus nodes together and manages traversal order (default is geographical: Left-to-Right, Top-to-Bottom).
* **Keyboard Events:** Widgets like `Focus` or `RawKeyboardListener` intercept keys (e.g., `Tab`, `Arrow Up/Down`, `Enter`, `Space`) to execute navigation or actions.

---

## 2. Global Component Design (Shared Level)

We have two types of shared components: **Search Filters** (used on search list screens) and **Form Inputs** (used in creation modals).

### A. Shared Dropdown Components
We have two main dropdown implementations depending on the design guidelines:
1. **`BuildDropDownWithSearch`** (`lib/components/build_dropdown_with_search.dart`)
   * **Usage:** Used on list filter headers (e.g., Invoice List, Customer Voucher List, Supplier Voucher List).
   * **Auto-Open:** Automatically opens the search pop-up as soon as it receives Tab focus.
   * **Visual Highlight:** Renders a primary brand-blue border and drop-shadow glow outline when focused.
2. **`CustomDropDownWithSearch`** (`lib/newcomponents/custom_dropdown_with_search.dart`)
   * **Usage:** Used inside creation modals (e.g., Create Invoice Modal).
   * **Auto-Open:** Does **not** auto-open on Tab focus (to avoid annoying form-filling experiences). The user can tap or use arrow keys to open.
   * **Keyboard Traversal:** Supports Arrow Up/Down to navigate options, Enter to select, and Tab to close and advance focus.

### B. Custom Calendar Pickers (`CalendarPickerTableCell`)
Located in `lib/components/build_calendar_selection.dart`:
* Wrapped inside a `Focus` widget listening to an optional `FocusNode`.
* **Auto-Open:** When tabbed onto, the calendar selector pops open automatically.
* **Keyboard Action:** If focused but closed, hitting **Enter** or **Space** triggers `_selectDate(context)`.
* **Loop Prevention:** An internal `_isPickerOpen` boolean flag tracks the modal state. When the calendar picker is dismissed, focus advances to the next node (`FocusScope.of(context).nextFocus()`) and resets after a brief delay. This prevents infinite picker popup loops.

---

## 3. Screen-Specific Orchestration (State Level)

Each individual screen decides its own tab navigation order by managing its focus tree:

```
[Customer Dropdown] ──(Tab)──> [Voucher Date] ──(Tab)──> [Type Dropdown] ──(Tab)──> [Item Name]
```

### Steps to implement focus on a screen:
1. **Declare FocusNodes** in the state class:
   ```dart
   final FocusNode customerFocus = FocusNode();
   final FocusNode voucherDateFocus = FocusNode();
   final FocusNode typeFocus = FocusNode();
   ```
2. **Pass FocusNodes** to the input widgets:
   ```dart
   BuildDropDownWithSearch<int>(
     focusNode: customerFocus,
     onChanged: (value) {
       // 3. Coordinate next focus programmatically!
       FocusScope.of(context).requestFocus(voucherDateFocus);
     },
   )
   ```
3. **Clean up resources** inside the screen's `dispose()` method:
   ```dart
   @override
   void dispose() {
     customerFocus.dispose();
     voucherDateFocus.dispose();
     typeFocus.dispose();
     super.dispose();
   }
   ```

### 3.1 Form Traversal & Focusable Reusable Buttons

For complex forms like **Create Expense**, we configure ordered tab traversal using Flutter's structured order classes:

1. **`FocusTraversalGroup` and `OrderedTraversalPolicy`:**
   * Wrapping the form container inside a `FocusTraversalGroup` tells Flutter to group these nodes together.
   * Applying `OrderedTraversalPolicy` allows us to enforce a strict sequential tab order using `FocusTraversalOrder` with a `NumericFocusOrder` on each field wrapper:
     ```dart
     FocusTraversalOrder(
       order: const NumericFocusOrder(1),
       child: TextField(...),
     )
     ```
2. **Focus Support in Reusable Buttons:**
   * Standard reusable buttons (e.g. `CustomRoundButtonAdvanced`) have been updated to accept a `FocusNode`.
   * The button container is wrapped in a `ListenableBuilder` tied to its focus node. When focused via keyboard tabbing, it displays matching brand-blue border outlines and soft drop shadow glows.

---

## 4. Item Table Focus Traversal (Voucher Row Flow)

For tables that support adding dynamic rows (e.g., Voucher Items), each item row has its own local set of FocusNodes:

```dart
class VoucherItem {
  final FocusNode itemNameFocus = FocusNode();
  final FocusNode unitAmountFocus = FocusNode();
  final FocusNode taxFocus = FocusNode();
  final FocusNode quantityFocus = FocusNode();
  final FocusNode plusFocus = FocusNode();
  
  void dispose() {
    itemNameFocus.dispose();
    unitAmountFocus.dispose();
    taxFocus.dispose();
    quantityFocus.dispose();
    plusFocus.dispose();
  }
}
```

### Row Flow Logic:
1. **Text Inputs Glow:** Each `TextFormField` is wrapped inside a `ListenableBuilder` listening to its respective focus node. When focused, it applies a border and a glowing shadow:
   ```dart
   border: hasFocus ? Border.all(color: ColorManager.kPrimaryColor, width: 1.2) : null,
   boxShadow: hasFocus ? [BoxShadow(color: ColorManager.kPrimaryColor.withOpacity(0.4), blurRadius: 6)] : null,
   ```
2. **Action Button Traversal:** Hitting **Tab** on the last input text field (Quantity) moves the focus onto the **`+` (Add Row) button** (via `item.plusFocus`).
3. **Interactive Add:** The `+` button highlights with a glowing blue shadow. Pressing **Enter** or **Space** adds a new row.
4. **Auto-Add row via Enter:** Hitting **Enter** inside the quantity text field itself also triggers the creation of a new row and automatically requests focus on the newly created row's first input:
   ```dart
   onFieldSubmitted: (_) {
     setState(() {
       voucherItems.add(VoucherItem());
     });
     Future.delayed(const Duration(milliseconds: 100), () {
       FocusScope.of(context).requestFocus(voucherItems[newIndex].itemNameFocus);
     });
   }
   ```

---

## 5. Visual Summary of Glow Highlights

* **Border Color:** `ColorManager.kPrimaryColor` (width 1.2px)
* **Shadow Color:** `ColorManager.kPrimaryColor.withOpacity(0.4)` (blur radius 6px)
* **Parent Shadow Behavior:** Standard grey drop-shadows are disabled while focused to keep the layout crisp.

---

## 6. Modified Files Reference

Here are the key implementation files that were updated or created for this keyboard focus system:

### Shared Components:
* **[build_calendar_selection.dart](file:///c:/Users/Mubashir/eposmob/lib/components/build_calendar_selection.dart)** — Focus wrapper, ListenableBuilder focus highlights, keyboard enter/space opening logic.
* **[build_dropdown_with_search.dart](file:///c:/Users/Mubashir/eposmob/lib/components/build_dropdown_with_search.dart)** — Keyboard listener, blue focus borders and shadow glow overlays.
* **[custom_round_button.dart](file:///c:/Users/Mubashir/eposmob/lib/newcomponents/custom_round_button.dart)** — Extended `CustomRoundButtonAdvanced` to support `FocusNode` parameters and display outline glow states on focus.

### List Filter Headers:
* **[customer_voucher_list.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/transactions/customer_voucher_list.dart)** — Filter dropdown FocusNodes declarations, disposes, and bindings.
* **[supplier_voucher_list.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/transactions/supplier_voucher_list.dart)** — Filter dropdown FocusNodes declarations, disposes, and bindings.
* **[expense_list_screen.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/transactions/expense_list_screen.dart)** — Integrated FocusNodes and traversal on general payment listing filter dropdowns and action buttons.

### Voucher & Expense Creation Screens:
* **[create_customer_voucher.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/transactions/widgets/create_customer_voucher.dart)** — Parent focus orchestration, items row inputs and plus button focus/glow wrappers.
* **[create_supplier_voucher.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/transactions/widgets/create_supplier_voucher.dart)** — State-level FocusNodes declarations, disposes, parent focus orchestration, items row inputs and plus button focus/glow wrappers.
* **[create_expense_screen.dart](file:///c:/Users/Mubashir/eposmob/lib/screens/transactions/create_expense_screen.dart)** — Ordered focus traversal group mapping, text field focus highlights, calendar date picker cell integration, and focusable reusable advanced button conversions.

### Documentation:
* **[KEYBOARD_NAVIGATION_GUIDE.md](file:///c:/Users/Mubashir/eposmob/docs/KEYBOARD_NAVIGATION_GUIDE.md)** — Detailed architecture and design guide (this document).

