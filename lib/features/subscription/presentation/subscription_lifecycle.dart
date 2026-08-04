import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/features/subscription/presentation/subscription_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

class SubscriptionLifecycle extends StatefulWidget {
  const SubscriptionLifecycle({required this.child, super.key});

  final Widget child;

  @override
  State<SubscriptionLifecycle> createState() => _SubscriptionLifecycleState();
}

class _SubscriptionLifecycleState extends State<SubscriptionLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<SubscriptionProvider>();
      provider.setFallbackLoader(
        context.read<AppSettingsProvider>().fetchCompanySubscriptionFallback,
      );
      await provider.hydrate();
      if (!mounted) return;
      await provider.refresh(notifyLoading: false);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SubscriptionProvider>().refresh(notifyLoading: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
