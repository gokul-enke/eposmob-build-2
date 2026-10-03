import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../tokens/app_colors.dart';
import '../tokens/app_spacing.dart';

/// Kind of message, which sets its colour, icon and default duration.
enum AppToastType {
  // Preserve the previous snackbar's Colors.green at 90% opacity.
  success(AppColors.successToast, Icons.check_circle_outline_rounded,
      Duration(seconds: 2)),
  info(AppColors.primary, Icons.info_outline_rounded, Duration(seconds: 3)),
  warning(AppColors.amber, Icons.warning_amber_rounded, Duration(seconds: 4)),
  error(AppColors.red, Icons.error_outline_rounded, Duration(seconds: 4));

  const AppToastType(this._background, this.icon, this.duration);

  final Color _background;
  Color get background => this == success
      ? _background.withValues(alpha: 0.9)
      : _background;
  final IconData icon;
  final Duration duration;
}

/// Where toasts sit on wide screens. Phones always use the full width.
enum AppToastPosition {
  start,
  center,
  end;

  /// Parses the stored setting (`left` / `center` / `right`). `left` and
  /// `right` mean the reading-direction start and end, so Arabic mirrors.
  static AppToastPosition fromSetting(String? value) => switch (value) {
        'center' => center,
        'right' => end,
        _ => start,
      };
}

/// The app's one way to show a short message on screen.
///
/// Messages are drawn in the root overlay, so they stay visible above open
/// dialogs and bottom sheets. Only one is shown at a time: a new message
/// replaces the current one. They sit above the system gesture bar and the
/// on-screen keyboard, and screen readers announce them.
///
/// ```dart
/// AppToast.success(context, savedMessage);
/// AppToast.error(context, message);
/// AppToast.show(context, 'Item removed', actionLabel: 'Undo', onAction: undo);
/// ```
abstract final class AppToast {
  /// Widest a toast gets on wide screens.
  static const maxWidth = 500.0;

  /// Below this screen width toasts span the width (minus margins).
  static const fullWidthBelow = 600.0;

  /// A toast with an action stays this long so there is time to press it.
  static const actionDuration = Duration(seconds: 5);

  /// Key of the visible toast (tests).
  static const toastKey = ValueKey('app_toast');

  /// Position on wide screens; set from the notification-position setting.
  static AppToastPosition position = AppToastPosition.start;

  static OverlayEntry? _entry;

  /// Whether a toast is on screen.
  static bool get isShowing => _entry != null;

  static void success(
    BuildContext context,
    Object? message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) =>
      show(context, message,
          type: AppToastType.success,
          actionLabel: actionLabel,
          onAction: onAction,
          duration: duration);

  static void error(BuildContext context, Object? message,
          {Duration? duration}) =>
      show(context, message, type: AppToastType.error, duration: duration);

  static void warning(BuildContext context, Object? message,
          {Duration? duration}) =>
      show(context, message, type: AppToastType.warning, duration: duration);

  static void info(BuildContext context, Object? message,
          {Duration? duration}) =>
      show(context, message, type: AppToastType.info, duration: duration);

  /// Shows [message], replacing any toast on screen. `null` or blank
  /// messages are ignored. [actionLabel] with [onAction] adds a button (e.g.
  /// "Undo") and keeps the toast for [actionDuration] unless [duration] is
  /// given.
  static void show(
    BuildContext context,
    Object? message, {
    AppToastType type = AppToastType.success,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final text = message?.toString().trim() ?? '';
    if (text.isEmpty) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      debugPrint('AppToast: no overlay to show "$text"');
      return;
    }

    dismiss();
    final hasAction = actionLabel != null && onAction != null;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) => _ToastPlacement(
        child: _Toast(
          key: toastKey,
          message: text,
          type: type,
          actionLabel: hasAction ? actionLabel : null,
          onAction: hasAction
              ? () {
                  _remove(entry);
                  onAction();
                }
              : null,
          duration: duration ?? (hasAction ? actionDuration : type.duration),
          onClose: () => _remove(entry),
          onDisposed: () => _forget(entry),
        ),
      ),
    );
    overlay.insert(entry);
    _entry = entry;
  }

  /// Removes the toast on screen, if any.
  static void dismiss() {
    final entry = _entry;
    if (entry != null) _remove(entry);
  }

  /// The toast's widget went away without being removed here (its overlay
  /// was torn down), so stop tracking it.
  static void _forget(OverlayEntry entry) {
    if (identical(_entry, entry)) _entry = null;
  }

  static void _remove(OverlayEntry entry) {
    if (!identical(_entry, entry)) return;
    _entry = null;
    if (entry.mounted) entry.remove();
  }
}

/// Bottom placement: full width on phones; [AppToast.maxWidth] at the
/// configured [AppToast.position] on wide screens. Clears the gesture bar and
/// the keyboard.
class _ToastPlacement extends StatelessWidget {
  const _ToastPlacement({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const margin = 16.0;
    final bottom = 20 + media.padding.bottom + media.viewInsets.bottom;
    final fullWidth = media.size.width < AppToast.fullWidthBelow;

    if (fullWidth) {
      return Positioned(
        left: margin,
        right: margin,
        bottom: bottom,
        child: child,
      );
    }

    final width = AppToast.maxWidth.clamp(0.0, media.size.width - margin * 2);
    return switch (AppToast.position) {
      AppToastPosition.center => Positioned(
          left: (media.size.width - width) / 2,
          bottom: bottom,
          width: width,
          child: child,
        ),
      AppToastPosition.start => PositionedDirectional(
          start: margin,
          bottom: bottom,
          width: width,
          child: child,
        ),
      AppToastPosition.end => PositionedDirectional(
          end: margin,
          bottom: bottom,
          width: width,
          child: child,
        ),
    };
  }
}

/// One toast. Owns its auto-dismiss timer, so the timer is cancelled with the
/// toast (replaced, closed, or its overlay torn down) — like a SnackBar.
class _Toast extends StatefulWidget {
  const _Toast({
    super.key,
    required this.message,
    required this.type,
    required this.duration,
    required this.onClose,
    required this.onDisposed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppToastType type;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;
  final VoidCallback onDisposed;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> {
  late final Timer _timer;

  String get message => widget.message;
  AppToastType get type => widget.type;
  String? get actionLabel => widget.actionLabel;
  VoidCallback? get onAction => widget.onAction;
  VoidCallback get onClose => widget.onClose;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, widget.onClose);
  }

  @override
  void dispose() {
    _timer.cancel();
    widget.onDisposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < AppToast.fullWidthBelow;
    const foreground = Colors.white;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Material(
          color: type.background,
          elevation: 6,
          shadowColor: AppColors.shadow,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              compact ? 12 : 16,
              compact ? 8 : 10,
              4,
              compact ? 8 : 10,
            ),
            child: Row(
              children: [
                Icon(type.icon, color: foreground, size: compact ? 20 : 22),
                SizedBox(width: compact ? AppSpacing.sm : 10),
                Expanded(
                  child: Text(
                    message,
                    maxLines: compact ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                  ),
                ),
                if (actionLabel != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: foreground,
                      textStyle: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    child: Text(actionLabel!),
                  ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded,
                      color: foreground, size: compact ? 18 : 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen "please wait" overlay for blocking work. One at a time.
abstract final class AppLoadingOverlay {
  static OverlayEntry? _entry;

  /// Key of the overlay (tests).
  static const overlayKey = ValueKey('app_loading_overlay');

  static bool get isShowing => _entry != null;

  /// Shows the overlay with [message] (default: "Please wait…"), replacing
  /// any overlay already shown.
  static void show(BuildContext context, {String? message}) {
    hide();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final text = message ?? 'general.please_wait'.tr;
    final entry = OverlayEntry(
      builder: (context) => Stack(
        key: overlayKey,
        children: [
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Color(0x59000000)),
          ),
          Center(
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.control + 2),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.6),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Flexible(
                        child: Text(
                          text,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.heading,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
    _entry = entry;
  }

  static void hide() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}
