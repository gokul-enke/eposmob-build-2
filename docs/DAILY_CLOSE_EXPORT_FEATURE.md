# Daily Sales Close Export Feature

## Overview

Added an **Export** button to the Daily Sales Close detail screen, next to the
existing **Print** button. Export generates the same Daily Close report as a
PDF and shares/opens it as a file, instead of sending it to a printer. Both
Print and Export pull their data from the same API-sourced
`DailySalesCloseData` object — no hardcoded report values.

## Files Modified

### `lib/screens/sales/daily_sales_close_detail.dart`

- **Added:** `import 'package:pos_machine/screens/print/daily_close_standard_printer.dart';`
- **Added:** `_handleExport(DailySalesCloseData data)` method — asks the user
  whether to include transactions, then calls
  `DailyCloseStandardPrinter(context).generateAndShareDailyClosePDF(...)`.
- **Added:** an "Export" `CustomRoundButton` in `_buildActionButtons`, next to
  the existing "Print" button (filled primary-color style vs Print's outlined
  style).
- **Changed:** `_askIncludeTransactions()` now takes an optional
  `{String action = 'Print'}` parameter and builds its title/body text from
  it (`"$action Transaction List?"` / `"...in this ${action.toLowerCase()}?"`),
  so the same dialog reads correctly for both flows.
- **Changed:** `_handlePrint` now calls `_askIncludeTransactions(action: 'Print')`;
  `_handleExport` calls `_askIncludeTransactions(action: 'Export')`.
- **Removed:** temporary debug `debugPrint` statements that were added during
  investigation (`print data.transactions:`, `export data.transactions:`,
  `export includeTransactions:`) — removed once the root cause was confirmed
  and fixed.
- **Unchanged:** `_handlePrint`'s printing logic, `_fetchDetails`, all other
  screen sections and comments.

### `lib/screens/print/daily_close_standard_printer.dart`

- **Added:** `generateAndShareDailyClosePDF({ data, selectedPaperSize, includeTransactions })` —
  builds the same report layout as `generateAndPrintDailyClosePDF`, saves the
  PDF, then shares/opens it instead of printing.
- **Changed:** the PDF layout inside `generateAndShareDailyClosePDF` from a
  single `pw.Page` to `pw.MultiPage`, so the `build` callback returns a
  `List<pw.Widget>` directly (no wrapping `pw.Column`/`return`), with
  `crossAxisAlignment: pw.CrossAxisAlignment.start` passed as a constructor
  param instead. This lets long transaction tables (30+ rows) automatically
  flow onto additional pages instead of being clipped on one fixed-size page.
- **Changed:** the output filename in `generateAndShareDailyClosePDF` from
  `DailyClose_$dateStr.pdf` to `DailyClose_${dateStr}_$timestamp.pdf` (using
  `DateTime.now().millisecondsSinceEpoch`), so repeated exports for the same
  closing date never overwrite each other or a viewer's cached copy.
- **Changed:** file handling after save is platform-aware — `Platform.isWindows`
  opens the file directly via `OpenFile.open` (share_plus doesn't reliably
  support sharing on Windows); other platforms use `Share.shareXFiles`.
- **Unchanged:** `generateAndPrintDailyClosePDF` (still uses `pw.Page` and the
  original fixed filename), font loading, `_getEposDirectory`, all shared
  helper widgets (`_buildInfoRow`, `_buildSummaryItem`, `_buildTableRow`,
  `_buildTableCell`, `_buildTableHeaderCell`), and all existing comments.

## Feature Flow

1. User opens a Daily Sales Close detail screen and taps **Export**.
2. `_handleExport(data)` shows the "Export Transaction List?" dialog via
   `_askIncludeTransactions(action: 'Export')`.
3. User picks **Yes**, **No**, or **Cancel**:
   - Cancel → dialog closes, nothing happens (`includeTransactions == null`).
   - Yes/No → `includeTransactions` is `true`/`false`.
4. `DailyCloseStandardPrinter(context).generateAndShareDailyClosePDF(data:, selectedPaperSize: 'A4', includeTransactions:)` runs:
   - Loads fonts, builds the PDF document via `pw.MultiPage`.
   - Includes the transactions table only if `includeTransactions` is `true`
     and `data.transactions` is non-empty.
   - Saves the file to `<Documents>/epos/DailyClose_<date>_<timestamp>.pdf`.
5. On Windows, the saved file is opened directly (`OpenFile.open`). On
   Android/iOS, the OS share sheet is invoked (`Share.shareXFiles`).
6. A scaffold message confirms the result ("PDF opened" / "PDF shared").

## Export vs Print Difference

| Aspect | Print | Export |
|---|---|---|
| Trigger | "Print" button | "Export" button |
| Handler | `_handlePrint` | `_handleExport` |
| Dialog wording | "Print Transaction List?" | "Export Transaction List?" |
| PDF generator | `generateAndPrintDailyClosePDF` | `generateAndShareDailyClosePDF` |
| PDF layout | `pw.Page` (single, fixed-size page) | `pw.MultiPage` (auto-paginates) |
| Output filename | `DailyClose_<date>.pdf` (fixed, overwrites on repeat) | `DailyClose_<date>_<timestamp>.pdf` (unique per export) |
| End action | Opens file / sends to a printing flow (`DailyClosePrintPage.autoPrint`, falls back to `DailyClosePrintPage`) | Opens (Windows) or shares (Android/iOS) the saved PDF |
| Data source | Same `DailySalesCloseData` object | Same `DailySalesCloseData` object |

## Platform Behavior

- **Windows:** `generateAndShareDailyClosePDF` saves the PDF, then calls
  `OpenFile.open(file.path)` to open it in the default PDF viewer. `share_plus`
  is not used on Windows because `Share.shareXFiles` is unreliable there
  ("We couldn't show you all the ways you could share" error).
- **Android/iOS:** the saved PDF is shared via `Share.shareXFiles([XFile(file.path)], subject: 'Daily Close Report')`,
  invoking the native share sheet.

## PDF Content

- **Without transactions (No):** Header, Sales Summary, Payment Breakdown, and
  Totals sections only. No "TRANSACTIONS" section is rendered.
- **With transactions (Yes):**
  - If `data.transactions` is non-empty, a "TRANSACTIONS" section with a full
    table (SL, Order No, Customer, Amount, Paid, Type, Time) is added.
  - If `includeTransactions` is `true` but `data.transactions` is empty/null
    while `data.totalOrders > 0`, a "TRANSACTIONS" heading with
    "(No transaction details available)" is shown instead of a table.
- **`pw.MultiPage` fix:** the export PDF previously used a single fixed-size
  `pw.Page`, which does not auto-paginate — a long transaction list (e.g. 34
  rows) could overflow and be clipped off the bottom of the page silently.
  Switching to `pw.MultiPage` lets the `pdf` package automatically flow
  content onto additional pages, so large transaction lists are no longer at
  risk of being cut off.

## Known Limitations

- `generateAndPrintDailyClosePDF` (the Print flow) still uses a single
  `pw.Page` and is not affected by the `pw.MultiPage` pagination fix — very
  long transaction lists printed via Print could still overflow a page.
- Exported files accumulate in `<Documents>/epos/` with unique timestamped
  names; there is no automatic cleanup of old export files.
- On Windows, `OpenFile.open` depends on there being a default PDF viewer
  registered on the machine; if none exists, the user only sees a "PDF saved"
  message with the file path instead of an opened viewer.
- The Export button always uses `selectedPaperSize: 'A4'` — there is no UI
  option to export as A5 (Print does support paper size selection upstream).

## Related Files

- `lib/screens/sales/daily_sales_close_detail.dart` — detail screen, Export/Print buttons, dialog, handlers.
- `lib/screens/print/daily_close_standard_printer.dart` — PDF generation for both Print (`generateAndPrintDailyClosePDF`) and Export (`generateAndShareDailyClosePDF`).
- `lib/screens/print/print_daily_close.dart` — `DailyClosePrintPage`, used by the Print flow (`autoPrint` / fallback print page).
- `lib/models/daily_sales_close.dart` — `DailySalesCloseData`, `DailySalesTransaction`, `CashSummary` models backing the report content.
- `lib/providers/sales_provider.dart` — `fetchDailySalesCloseDetail`, `selectedDailySalesCloseData` (API-sourced data used by both Print and Export).
