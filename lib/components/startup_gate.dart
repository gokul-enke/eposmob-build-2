import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/resources/recovery_text.dart';
import 'package:pos_machine/resources/localization_service.dart';

/// Paints before invoking initialization. A timed-out initializer can never
/// replace the failure screen with a late successful application.
class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    required this.initialize,
    required this.onClose,
  });

  final Future<Widget> Function(ValueChanged<String> reportStage) initialize;
  final VoidCallback onClose;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  String _stage = 'Opening CloudPOS…';
  Object? _error;
  Widget? _application;
  Timer? _slowTimer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    if (!mounted) return;
    _slowTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _slow = true);
    });
    try {
      final application = await widget.initialize((stage) {
        if (mounted && _error == null) setState(() => _stage = stage);
      });
      if (mounted) setState(() => _application = application);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _slowTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_application != null) return _application!;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CLOUDPOS',
      home: Scaffold(
        backgroundColor: const Color(0xFFF7F9FC),
        body: Directionality(
            textDirection: LocalizationService.locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded,
                          size: 56, color: Color(0xFF1967D2)),
                      const SizedBox(height: 20),
                      const Text('CloudPOS',
                          style: TextStyle(
                              fontSize: 30, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 32),
                      if (_error == null) ...[
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 24),
                        Text(
                            recoveryText(_slow
                                ? 'Still getting ready…'
                                : 'Getting your counter ready…'),
                            key: const ValueKey('startup-title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text(recoveryText(_stage),
                            key: const ValueKey('startup-stage'),
                            textAlign: TextAlign.center),
                        if (_slow) ...[
                          const SizedBox(height: 12),
                          Text(
                              recoveryText(
                                  'Please keep CloudPOS open while your saved data loads.'),
                              textAlign: TextAlign.center),
                        ],
                      ] else ...[
                        Text(recoveryText('CloudPOS couldn’t finish starting'),
                            key: const ValueKey('startup-error'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        Text(
                            recoveryText(
                                'We couldn’t load the data needed to open your counter. '
                                'Close CloudPOS and open it again. If this continues, '
                                'share the error details with support.'),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          title: Text(recoveryText('Error details')),
                          children: [SelectableText('Stage: $_stage\n$_error')],
                        ),
                        const SizedBox(height: 20),
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          OutlinedButton(
                            onPressed: () => Clipboard.setData(ClipboardData(
                                text:
                                    'CloudPOS startup\nStage: $_stage\n$_error')),
                            child: Text(recoveryText('Copy error details')),
                          ),
                          FilledButton(
                              onPressed: widget.onClose,
                              child: Text(recoveryText('Close CloudPOS'))),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            )),
      ),
    );
  }
}
