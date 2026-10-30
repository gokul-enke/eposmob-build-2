import 'package:flutter/material.dart';
import 'package:pos_machine/services/order_submission_coordinator.dart';

/// Prevents cart edits without detaching the barcode field's focus.
class OrderSubmissionGuard extends StatelessWidget {
  const OrderSubmissionGuard(
      {super.key, required this.child, this.coordinator, this.busy = false});
  final Widget child;
  final OrderSubmissionCoordinator? coordinator;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final state = coordinator ?? OrderSubmissionCoordinator.instance;
    return ListenableBuilder(
        listenable: state,
        builder: (_, __) => PopScope(
            canPop: !(busy || state.isBusy),
            child: Focus(
                canRequestFocus: false,
                onKeyEvent: (_, __) => busy || state.isBusy
                    ? KeyEventResult.handled
                    : KeyEventResult.ignored,
                child: AbsorbPointer(
                    absorbing: busy || state.isBusy, child: child))));
  }
}

/// Whether the screen below is the one shown. A list kept alive behind its
/// own details (see [CheckoutNavigationHost.keepListFor]) is not.
class ScreenVisibility extends InheritedWidget {
  const ScreenVisibility(
      {super.key, required this.visible, required super.child});
  final bool visible;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenVisibility>()?.visible ??
      true;

  @override
  bool updateShouldNotify(ScreenVisibility oldWidget) =>
      visible != oldWidget.visible;
}

/// Defers sidebar navigation until checkout's UI completion (including receipt
/// handling) finishes, so a disposed billing page cannot silently skip cleanup.
class CheckoutNavigationHost extends StatefulWidget {
  const CheckoutNavigationHost(
      {super.key,
      required this.index,
      required this.screen,
      this.coordinator,
      this.keepListFor = const {},
      this.onListHidden});
  final int index;
  final Widget Function(int) screen;
  final OrderSubmissionCoordinator? coordinator;

  /// List screen index -> its own detail screen indexes. Opening one of those
  /// details keeps the list mounted, offstage, so going back shows it as the
  /// user left it: filters, page and scroll. Going anywhere else drops it.
  final Map<int, Set<int>> keepListFor;

  /// Runs after a list is hidden behind its details (e.g. to close the
  /// on-screen keyboard bound to one of its fields).
  final VoidCallback? onListHidden;
  @override
  State<CheckoutNavigationHost> createState() => _CheckoutNavigationHostState();
}

class _CheckoutNavigationHostState extends State<CheckoutNavigationHost> {
  late int _visibleIndex = widget.index;
  int? _keptIndex;

  bool _isDetailOf(int list, int index) =>
      widget.keepListFor[list]?.contains(index) ?? false;

  void _show(int index) {
    if (index == _visibleIndex) return;
    final kept = _keptIndex;
    if (_isDetailOf(_visibleIndex, index)) {
      _keptIndex = _visibleIndex;
      final hidden = widget.onListHidden;
      if (hidden != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => hidden());
      }
    } else if (kept != null && (index == kept || !_isDetailOf(kept, index))) {
      // Back on the kept list (shown again), or somewhere else (dropped).
      _keptIndex = null;
    }
    _visibleIndex = index;
  }

  /// Same shape for every screen, so a kept list keeps its State when it
  /// moves between shown and hidden. Only kept-able lists get their own key;
  /// other screens share one, as before (billing and alias slots reuse it).
  Widget _slot(int index, {required bool visible}) => KeyedSubtree(
        key: widget.keepListFor.containsKey(index)
            ? ValueKey<int>(index)
            : const ValueKey<String>('screen'),
        child: ScreenVisibility(
          visible: visible,
          child: ExcludeFocus(
            excluding: !visible,
            child: Offstage(
              offstage: !visible,
              child: TickerMode(enabled: visible, child: widget.screen(index)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = widget.coordinator ?? OrderSubmissionCoordinator.instance;
    return ListenableBuilder(
        listenable: state,
        builder: (_, __) {
          if (!state.isBusy) _show(widget.index);
          final kept = _keptIndex;
          return Stack(fit: StackFit.passthrough, children: [
            if (kept != null) _slot(kept, visible: false),
            _slot(_visibleIndex, visible: true),
          ]);
        });
  }
}
