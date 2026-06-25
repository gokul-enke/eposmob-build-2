# Mobile Billing UI — Intern Guide

> **Who this is for:** you're working on **how the mobile billing screen looks**, not how it
> works. You do **not** need to understand the billing logic. This guide tells you exactly
> which files are yours, which lines you can change, and how to check your work.

---

## 0. The one rule

> **Change how things _look_. Never change what data goes _in_ or what happens on _tap_.**

If you follow this, you physically cannot break the billing logic. The worst you can do is
make something look wrong — and you'll see that immediately on screen.

---

## 1. What "mobile" means here

The mobile layout only shows when the window/screen is **narrower than 650px**. Anything
wider shows the **desktop** screen, which is a completely different file you must **never
touch** (`presentation/pages/billing_page.dart`).

So: run the app in a **phone-sized window** or on a **real phone** to see your work.

---

## 2. Your files — the ONLY folder you edit

```
lib/features/billing/presentation/widgets/mobile/
├── home_tab.dart          ← "Home" tab layout
├── billing_tab.dart       ← "Billing & Payment" tab layout
├── orders_tab.dart        ← "Orders" tab layout
├── home/
│   ├── mobile_home_app_bar.dart
│   └── mobile_home_cart_card.dart
├── billing/
│   ├── billing_section_card.dart      ← titled card wrapper
│   ├── billing_option_button.dart     ← small bordered button
│   ├── payment_methods_section.dart
│   ├── pine_labs_section.dart
│   ├── delivery_options_section.dart
│   ├── coupon_section.dart
│   └── billing_action_buttons.dart    ← Save / Print / Confirm bar
└── orders/
    ├── mobile_order_card.dart         ← one saved-order card
    └── orders_empty_state.dart
```

You may also use the shared theme files (read-only — see §5):
`lib/resources/color_manager.dart`, `font_manager.dart`, `style_manager.dart`.

---

## 3. DO NOT OPEN these

| File / folder | Why |
|---|---|
| `presentation/pages/billing_page.dart` | The **desktop** screen. Not mobile. Off limits. |
| `presentation/pages/billing_page_mobile.dart` | Wiring/orchestration. Not styling. |
| `controllers/billing_mobile_controller.dart` | The billing logic. |
| `domain/` (any file) | Pure calculation logic. |
| `providers/` (any file, anywhere) | The app's "brain" — data & state. |

If you think you need to change one of these to make something look right, **stop and ask** —
there's almost always a UI-only way to do it.

---

## 4. The three kinds of code — and which lines are yours

Open any widget file and you'll see three kinds of code. **You only edit the first kind.**

### ✅ YOURS — visual code (change freely)
- `Container`, `Padding`, `Row`, `Column`, `SizedBox`, `Expanded`
- `decoration:`, `padding:`, `margin:`, `borderRadius:`
- `TextStyle(...)`, `fontSize`, `fontWeight`, colors, icons, `size:`
- the **order** of visual elements
- adding/removing decorative widgets (a divider, spacing, an icon)

### 🚫 NOT YOURS — leave exactly as written
- The `class ... extends StatelessWidget` line and the `final` fields below it
  (these are the **inputs** — renaming/removing one breaks the screen).
- `Consumer<SomethingProvider>(...)` and `Provider.of<...>(context)` lines
  (this is **where the data comes from**).
- Anything inside `onTap:` / `onPressed:` (this is **what the button does**).
- Method/function names being called, e.g. `provider.getSelectedPaymentMethodsExcludingEmpty()`.

---

## 5. Annotated example

Here's a **real** file from your project — `billing/billing_option_button.dart` — marked up
so you can see exactly which lines are yours.

```dart
class BillingOptionButton extends StatelessWidget {
  final String title;          // 🚫 INPUT — do not rename/remove
  final IconData icon;         // 🚫 INPUT
  final VoidCallback onTap;    // 🚫 INPUT (the action)

  const BillingOptionButton({  // 🚫 keep this constructor exactly as-is
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,            // 🚫 the action — don't touch
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), // ✅ yours
        decoration: BoxDecoration(
          color: Colors.white,                          // ✅ yours
          borderRadius: BorderRadius.circular(8),       // ✅ yours
          border: Border.all(color: Colors.grey.shade300), // ✅ yours
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,  // ✅ yours
          children: [
            Icon(icon, color: Colors.grey.shade600, size: 16), // ✅ color/size yours; `icon` stays
            const SizedBox(width: 4),                   // ✅ yours
            Text(
              title,                                    // 🚫 keep `title` — it's the input
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700), // ✅ yours
            ),
          ],
        ),
      ),
    );
  }
}
```

**Rule of thumb:** if a value is a `final` field name (`title`, `icon`, `onTap`), keep it.
Everything around it that controls appearance is yours.

---

## 6. Use the theme, not random colors

Instead of raw `Colors.x` or hex codes, prefer the shared palette in
`lib/resources/color_manager.dart` so the app stays consistent. Examples already in use:

```dart
ColorManager.kPrimaryColor    // brand blue  (0xFF3C92F5)
ColorManager.kTitleTextColor  // dark heading text
ColorManager.kTextColor       // body text
ColorManager.kGreyColor       // muted/secondary text
ColorManager.kButtonGreen / kButtonRed / kButtonBlue
```

When you need a color, **check `color_manager.dart` first** for one that fits before
hardcoding a new one. If a color you need genuinely doesn't exist, ask before adding one.

---

## 7. The "one widget = one job" idea

Each small widget controls **one look** used in many places. For example,
`billing_section_card.dart` is the titled card used by *every* section on the Billing tab.

- Want all section cards to look different? Edit `billing_section_card.dart` **once** — they
  all update.
- **Don't** copy-paste the same styling into multiple files. If you're pasting, you're
  probably in the wrong place — find the shared widget instead.

---

## 8. Your workflow (every change)

1. Run the app in a phone-sized window (or real device).
2. Change **one** widget.
3. Hot reload (`r` in the Flutter terminal) and look at it.
4. When the widget looks right, run these two checks before moving on:
   ```bash
   flutter analyze     # must say: No issues found / 0 errors
   flutter test        # must stay green (currently 201 tests pass)
   ```
5. If `flutter test` goes red, you changed something from §4's "NOT YOURS" list — undo that
   part. Tests going red is your safety alarm.
6. Commit small — **one widget per commit**, with a clear message.

---

## 9. When to ask (don't guess)

- You think you must edit a file from the §3 "do not open" list.
- A change needs new data that isn't already passed into the widget.
- `flutter analyze` shows an error you don't understand.
- You're about to copy-paste styling between files.
- You want to add a new color/font to the theme.

A 30-second question is always cheaper than a broken billing screen. 🙂
