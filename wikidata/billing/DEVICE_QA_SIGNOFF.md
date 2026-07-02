# Mobile Billing — Device QA Sign-off Sheet

> **Purpose:** the last release-gate item in `todo.md` ("Manual Device QA") requires a
> human with physical POS hardware. This sheet makes that pass fast, thorough, and
> auditable. Every row lists the **exact expected result derived from the current code**,
> so the tester only has to compare, mark PASS/FAIL, and sign.
>
> **Code state at hand-off (2026-07-01):** `flutter analyze` mobile tree = *No issues found*;
> full suite = **+409 −0**; all code-level defects fixed. This sheet is the only remaining gate.

**Build under test:** `__________________`  **Tester:** `__________`  **Date:** `__________`

---

## 0. Device matrix (repeat §1–§6 per device)

| # | Device | OS | Orientation | Done |
|---|---|---|---|---|
| A | Small Android phone (~5") | | Portrait | ☐ |
| B | Small Android phone | | Landscape | ☐ |
| C | Android tablet | | Portrait | ☐ |
| D | Android tablet | | Landscape | ☐ |

> Mobile layout renders below **650px** width (`Breakpoints.isMobileWidth`). On a tablet in
> landscape you may cross into the desktop layout — that is expected; note which layout showed.

---

## 1. Core sale — product cards → cash → confirm

| Step | Expected (from code) | Result |
|---|---|---|
| Open Market tab | Product grid renders; prices show **tenant currency** (e.g. `INR 10.00`), never hardcoded `SAR` | ☐ P ☐ F |
| Tap **Add** on an out-of-stock card | Still adds (stock decided by `ProductCartHelper`, not the card); "Out of Stock" badge stays visual-only | ☐ P ☐ F |
| Open Cart tab | Cart badge count matches items; summary currency + VAT% match the Billing tab exactly | ☐ P ☐ F |
| Billing tab → select CASH → **Exact cash** | Cash field fills the full payable; balance = 0 | ☐ P ☐ F |
| **Confirm** | One order created; success message; cart cleared; stock NOT restored | ☐ P ☐ F |
| Double-tap **Confirm** fast | Only **one** API order (busy guard) | ☐ P ☐ F |

## 2. Barcode scanner (real wedge)

| Step | Expected | Result |
|---|---|---|
| Burst-scan 10 known products rapidly | All 10 added, in scan order (FIFO `BarcodeScanQueue`), none dropped | ☐ P ☐ F |
| Scan an unknown barcode | Opens Add-Product-with-barcode modal (`isAddToCart:true`) | ☐ P ☐ F |
| Scan an embedded weight barcode (14-char `000…`, KG) | Quantity parsed from the embedded weight | ☐ P ☐ F |
| Scan a sale-unit barcode | Adds with the correct sale unit (conversion rate **> 1** only; rate `1` = base product — see `MOBILE_DESKTOP_PARITY.md` P-01) | ☐ P ☐ F |
| Scan unknown barcode → create with qty **3** | Cart line qty **3** after save (not hardcoded 1 — P-02) | ☐ P ☐ F |
| One bad scan mid-burst | Later queued scans still process | ☐ P ☐ F |

## 3. Thermal printer (real BT/USB)

| Step | Expected | Result |
|---|---|---|
| **Confirm & Print** a mixed order | Receipt prints: currency, per-line tax, discount, delivery charge, sale-unit lines, customer credit — all correct | ☐ P ☐ F |
| Dynamic method (e.g. CHEQUE) in payment | Prints in the payment breakdown | ☐ P ☐ F |
| Kill printer power, then Confirm & Print | Order still **confirmed**; "Print failed — Retry" snackbar appears | ☐ P ☐ F |
| Tap **Retry** with printer back on | Prints without creating a second order | ☐ P ☐ F |
| Reprint a saved order from Orders tab | Prints via saved-order path | ☐ P ☐ F |

## 4. Pine Labs terminal (real device)

| Step | Expected | Result |
|---|---|---|
| Pay with Pine Labs — approve | ONLINE selected; transaction reference stored; button shows "Paid with Pinelabs ✓" | ☐ P ☐ F |
| Confirm after terminal success | One ONLINE payment row + one reference | ☐ P ☐ F |
| Pay with Pine Labs — decline | ONLINE deselected; cannot confirm as paid; error offers retry/alternate | ☐ P ☐ F |
| Cancel / timeout at terminal | No false "paid" state; safe to retry or pick another method | ☐ P ☐ F |

## 5. Feature parity spot-checks

| Step | Expected | Result |
|---|---|---|
| Apply flat & percentage discount / coupon | Payable updates; selected CASH remaps to new total; balance recalculates | ☐ P ☐ F |
| Split CASH + CARD, then apply coupon | Manually-split amounts are **not** destroyed | ☐ P ☐ F |
| Car Delivery without car number → Confirm | Blocked with "Please enter Car Number" | ☐ P ☐ F |
| Door Delivery | Saved-address chips appear; address persists | ☐ P ☐ F |
| `askDeliveryDate` ON | Delivery date + time controls show and persist | ☐ P ☐ F |
| `barcodeSales` OFF → product search | Autocomplete shows **sellable** products only (P-03) | ☐ P ☐ F |
| Desktop: unknown barcode → create with qty **3** | Cart line qty **3** after save (P-04; same path as P-02) | ☐ P ☐ F |
| Product with 2+ variants → Add | Variant picker sheet; in-stock variant added at variant price (P-05) | ☐ P ☐ F |
| Single-variant product, variant qty 0 → Add | Blocked with out-of-stock message; no cart line (P-05 slice 3) | ☐ P ☐ F |
| Out-of-stock variant in picker | Row greyed, not tappable; Add disabled until in-stock variant chosen (P-05) | ☐ P ☐ F |
| Scan variant barcode on multi-variant product | Adds that variant directly, no picker (P-05) | ☐ P ☐ F |
| Scan OOS variant barcode (multi-variant product) | Does not auto-add OOS line; picker or alternate path (P-05) | ☐ P ☐ F |
| Variant cart line → Confirm | API `items[]` includes `product_variant_id` (P-05) | ☐ P ☐ F |
| Save draft with variant → reload from Orders | `variantId`, display name `(Red \| L)`, price/qty restored (P-05 slice 2) | ☐ P ☐ F |
| App kill/reopen with variant in active cart | Cart line still shows variant label (Hive fields 16–17) (P-05 slice 2) | ☐ P ☐ F |
| Product with variants **and** sale units | Separate lines per variant; sale-unit qty/price conversion intact (P-05 slice 4) | ☐ P ☐ F |
| Customer with previous balance | Balance shown; credit toggle feeds payment correctly | ☐ P ☐ F |
| Save draft → reopen from Orders → edit | Customer, delivery, coupon, payments, dynamic methods, stock all rehydrate | ☐ P ☐ F |
| Save draft with **invalid** price | Save blocked; **cart NOT cleared** | ☐ P ☐ F |

## 6. Stress / resilience

| Step | Expected | Result |
|---|---|---|
| Airplane mode → Confirm | Blocked: "No internet… save locally"; cart intact | ☐ P ☐ F |
| Airplane mode → Save draft | Works (Hive, offline) | ☐ P ☐ F |
| Background the app mid-cart, resume | Cart + state preserved; stale busy flags cleared | ☐ P ☐ F |
| Drop network during Confirm | No duplicate order; cart preserved; actionable error | ☐ P ☐ F |
| Low battery / long session | No crash; no data loss | ☐ P ☐ F |
| Small phone, keyboard open on payment | Nothing critical clipped; content scrolls above the action bar | ☐ P ☐ F |

---

## Sign-off

- [ ] All rows PASS on all four device rows (A–D)
- [ ] Any FAIL logged with repro + screenshot and handed back to engineering

**QA sign-off:** `______________________`  **Date:** `__________`

> On completion, check **"Manual device QA completed"** in `todo.md` and the Release Gate is met.
