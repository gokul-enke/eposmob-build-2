import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class KioskInactivityGuard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReset;
  final Duration idleDuration;
  final int warningSeconds;

  const KioskInactivityGuard({
    super.key,
    required this.child,
    this.onReset,
    this.idleDuration = const Duration(minutes: 2),
    this.warningSeconds = 15,
  });

  @override
  State<KioskInactivityGuard> createState() => _KioskInactivityGuardState();
}

class _KioskInactivityGuardState extends State<KioskInactivityGuard> {
  Timer? _timer;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant KioskInactivityGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idleDuration != widget.idleDuration) _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_dialogOpen) return;
    _timer = Timer(widget.idleDuration, _handleIdleTimeout);
  }

  Future<void> _handleIdleTimeout() async {
    if (!mounted) return;
    if (ModalRoute.of(context)?.isCurrent != true) {
      _restartTimer();
      return;
    }

    _dialogOpen = true;
    final continueSession = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _InactivityDialog(
        seconds: widget.warningSeconds,
      ),
    );
    _dialogOpen = false;
    if (!mounted) return;

    if (continueSession == true) {
      _restartTimer();
    } else {
      _resetSession();
    }
  }

  void _resetSession() {
    _timer?.cancel();
    if (widget.onReset != null) {
      widget.onReset!();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restartTimer(),
      onPointerMove: (_) => _restartTimer(),
      child: widget.child,
    );
  }
}

class _InactivityDialog extends StatefulWidget {
  final int seconds;

  const _InactivityDialog({required this.seconds});

  @override
  State<_InactivityDialog> createState() => _InactivityDialogState();
}

class _InactivityDialogState extends State<_InactivityDialog> {
  Timer? _countdown;
  late int _secondsLeft;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.seconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _countdown?.cancel();
        Navigator.of(context).pop(false);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: const BoxDecoration(
                    color: ColorManager.kPrimaryWithOpacity10,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: ColorManager.kPrimaryColor,
                    size: 42,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Are you still there?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ColorManager.kTitleTextColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'This order will reset in $_secondsLeft seconds to protect your privacy.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ColorManager.kTextColor,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: ColorManager.kPrimaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Continue my order',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel order and start over'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
