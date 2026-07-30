import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos_machine/features/realtime_sync/presentation/realtime_sync_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:provider/provider.dart';

class RealtimeSyncLifecycle extends StatefulWidget {
  const RealtimeSyncLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<RealtimeSyncLifecycle> createState() => _RealtimeSyncLifecycleState();
}

class _RealtimeSyncLifecycleState extends State<RealtimeSyncLifecycle>
    with WidgetsBindingObserver {
  BillingProvider? _billing;
  bool? _lastOnline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final billing = context.read<BillingProvider>();
      _billing = billing;
      _lastOnline = billing.hasInternet;
      billing.addListener(_handleConnectivity);
      billing.initConnectivityListener();
      unawaited(
        context.read<RealtimeSyncProvider>().setOnline(billing.hasInternet),
      );
    });
  }

  void _handleConnectivity() {
    final billing = _billing;
    if (!mounted || billing == null) return;
    final online = billing.hasInternet;
    if (_lastOnline == online) return;
    _lastOnline = online;
    unawaited(context.read<RealtimeSyncProvider>().setOnline(online));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    final realtime = context.read<RealtimeSyncProvider>();
    if (state == AppLifecycleState.resumed) {
      unawaited(realtime.resume());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(realtime.pause());
    }
  }

  @override
  void dispose() {
    _billing?.removeListener(_handleConnectivity);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
