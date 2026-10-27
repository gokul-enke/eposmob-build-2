import 'package:flutter/widgets.dart';

/// Disposes [controllers] when this widget leaves the tree.
///
/// Wrap a dialog's content in it instead of disposing the controllers right
/// after `await showDialog(...)` returns: the future completes when the route
/// is popped, but its text fields keep rebuilding during the exit animation,
/// and a disposed controller there throws and takes the app down.
class ControllerOwner extends StatefulWidget {
  const ControllerOwner({
    super.key,
    required this.controllers,
    required this.child,
  });

  final List<ChangeNotifier> controllers;
  final Widget child;

  @override
  State<ControllerOwner> createState() => _ControllerOwnerState();
}

class _ControllerOwnerState extends State<ControllerOwner> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
