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

/// Defers sidebar navigation until checkout's UI completion (including receipt
/// handling) finishes, so a disposed billing page cannot silently skip cleanup.
class CheckoutNavigationHost extends StatefulWidget {
  const CheckoutNavigationHost(
      {super.key, required this.index, required this.screen, this.coordinator});
  final int index;
  final Widget Function(int) screen;
  final OrderSubmissionCoordinator? coordinator;
  @override
  State<CheckoutNavigationHost> createState() => _CheckoutNavigationHostState();
}

class _CheckoutNavigationHostState extends State<CheckoutNavigationHost> {
  late int _visibleIndex = widget.index;
  @override
  Widget build(BuildContext context) {
    final state = widget.coordinator ?? OrderSubmissionCoordinator.instance;
    return ListenableBuilder(
        listenable: state,
        builder: (_, __) {
          if (!state.isBusy) _visibleIndex = widget.index;
          return widget.screen(_visibleIndex);
        });
  }
}
