import 'package:flutter/material.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';

// Compatibility layer for the app's original message helpers.
//
// The implementation lives in the UI kit: `AppToast` and `AppLoadingOverlay`
// (lib/core/ui/feedback/app_toast.dart). These functions keep the old names
// and signatures so existing screens work unchanged; new code should call
// `AppToast.success / error / warning / info` directly.
//
// `components/build_dialog_box.dart` re-exports these same functions, so the
// whole app shares one message on screen and one position setting.

/// Sets where messages appear on wide screens: `left`, `center` or `right`
/// (start / centre / end in right-to-left languages).
void setNotificationPosition(String position) {
  AppToast.position = AppToastPosition.fromSetting(position);
}

/// Success message. [actionLabel] and [onAction] add a button such as
/// "Undo"; the message then stays for 5 seconds instead of 2.
///
/// Prefer [AppToast.success].
ScaffoldMessengerState showScaffold({
  required BuildContext context,
  message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  AppToast.success(
    context,
    message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
  return ScaffoldMessenger.of(context);
}

/// Error message, shown for 4 seconds.
///
/// Prefer [AppToast.error].
ScaffoldMessengerState showScaffoldError({
  required BuildContext context,
  required String message,
}) {
  AppToast.error(context, message);
  return ScaffoldMessenger.of(context);
}

/// Blocking "please wait" overlay. Prefer [AppLoadingOverlay.show].
void showLoadingOverlay(BuildContext context, {String? message}) =>
    AppLoadingOverlay.show(context, message: message);

/// Prefer [AppLoadingOverlay.hide].
void hideLoadingOverlay() => AppLoadingOverlay.hide();
