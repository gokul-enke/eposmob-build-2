# Compulsory Shift Open — Implementation Notes

## Overview

The **"Shift Not Opened"** dialog on the Billing screen is gated behind the
`COMPULSORY_SHIFT_OPEN_` company property. When the prop is disabled (the
default), the dialog is never shown and no extra API call is made. When it is
enabled, the app checks whether a shift is open and forces the user to open one
before starting sales.

---

## Company Property

| Key | `COMPULSORY_SHIFT_OPEN_` |
|---|---|
| **Type** | Boolean |
| **Default** | `false` |
| **Effect when false** | Shift check is skipped entirely — no API call, no dialog |
| **Effect when true** | Shift status is fetched; if no open shift exists the user must open one |

> **Note:** The trailing underscore in `COMPULSORY_SHIFT_OPEN_` is intentional —
> it matches the key as it appears in the backend company-props API.

---

## Files Changed

### 1. `lib/models/get_app_settings.dart`

**Field declaration** (after `allowOverselling`):
```dart
final bool compulsoryShiftOpen;
```

**Constructor parameter** (optional, defaults to `false`):
```dart
this.compulsoryShiftOpen = false,
```

**`fromJson` — parsed via the shared `_readSettingStatus()` helper:**
```dart
compulsoryShiftOpen: _readSettingStatus(
  settingsMap,
  'COMPULSORY_SHIFT_OPEN_',
  defaultValue: false,
),
```

**`toJson` — serialised back for completeness:**
```dart
{
  "name": "Compulsory Shift Open",
  "code": "COMPULSORY_SHIFT_OPEN_",
  "value": "",
  "status": compulsoryShiftOpen.toString(),
},
```

---

### 2. `lib/features/billing/presentation/pages/billing_page.dart`

**Method:** `_checkOpenShiftRequired()` (called from `initState` →
`addPostFrameCallback`)

**Gate added at the very top of the method, before any API call:**
```dart
Future<void> _checkOpenShiftRequired() async {
  if (!mounted) return;
  try {
    // ── NEW: gate on company prop ────────────────────────────────────────
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final compulsoryShiftOpen =
        appSettingsProvider.appSettings?.compulsoryShiftOpen ?? false;
    if (!compulsoryShiftOpen) return;
    // ────────────────────────────────────────────────────────────────────

    final authModel = Provider.of<AuthModel>(context, listen: false);
    final storeSession =
        Provider.of<StoreSessionProvider>(context, listen: false);
    final salesProvider = SalesProvider();

    final pendingStatus = await salesProvider.fetchDayClosePendingStatus(
      accessToken: authModel.token ?? '',
      storeId: storeSession.activeStore?.storeId ?? 0,
      userId: authModel.userId ?? 0,
    );

    if (!mounted) return;

    // canOpenShift true = no open shift exists
    if (pendingStatus?.canOpenShift == true) {
      _showOpenShiftRequiredAlert();
    }
  } catch (e) {
    debugPrint('_checkOpenShiftRequired error: $e');
  }
}
```

`_showOpenShiftRequiredAlert()` was **not modified**.

---

## Behaviour Matrix

| `COMPULSORY_SHIFT_OPEN_` | Shift open? | Result |
|---|---|---|
| `false` (default) | any | Method returns immediately — no network call, no dialog |
| `true` | Yes (`canOpenShift == false`) | No dialog — user proceeds normally |
| `true` | No (`canOpenShift == true`) | **"Shift Not Opened"** dialog shown with **Open Shift** / **Go Back** buttons |

---

## "Shift Not Opened" Dialog

Rendered by `_showOpenShiftRequiredAlert()` in `billing_page.dart`:

- `barrierDismissible: false` — cannot be dismissed by tapping outside
- **Open Shift** — dismisses the alert and opens `OpenShiftModal`
- **Go Back** — dismisses the alert and pops the billing screen

---

## How `AppSettingsProvider` Works

`AppSettingsProvider` (`lib/providers/app_settings_provider.dart`) is a
`ChangeNotifier` that fetches all company props from the backend on startup via
`fetchAppSettings()`. Props are parsed into the `AppSettings` model
(`lib/models/get_app_settings.dart`) using the private `_readSettingStatus()`
helper, which normalises raw API values (`"true"`, `"1"`, `true`, `1`) into a
Dart `bool`.

Reading the prop anywhere in the widget tree:
```dart
final appSettingsProvider =
    Provider.of<AppSettingsProvider>(context, listen: false);
final compulsoryShiftOpen =
    appSettingsProvider.appSettings?.compulsoryShiftOpen ?? false;
```

---

## Related Company Props (same pattern)

| Field | JSON key | Default |
|---|---|---|
| `compulsoryDayCloseRegister` | `COMPULSORY_DAY_CLOSE_REGISTER` | `false` |
| `productVariantEnabled` | `PRODUCT_VARIANT_ENABLED` | `false` |
| `allowOverselling` | `ALLOW_OVERSELL` | `true` |
| `compulsoryShiftOpen` | `COMPULSORY_SHIFT_OPEN_` | `false` |
