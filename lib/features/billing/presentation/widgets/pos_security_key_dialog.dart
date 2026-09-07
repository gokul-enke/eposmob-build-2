import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

/// Provides the optional cashier guard for destructive POS cart actions.
///
/// The setting is deliberately checked at the point of action. This keeps
/// automatic cart resets (for example after a completed sale) independent of
/// the user-facing clear/remove/delete actions that require authorization.
class PosSecurityKeyDialog {
  PosSecurityKeyDialog._();

  static const String settingCode = 'POS_AUTHENTICATE_CLEARCART';
  static const String inputKey = 'pos_security_key_input';
  static const String verifyButtonKey = 'pos_security_key_verify';
  static const String cancelButtonKey = 'pos_security_key_cancel';

  static Future<bool> verify(
    BuildContext context, {
    required String action,
  }) async {
    final settings =
        Provider.of<AppSettingsProvider>(context, listen: false).appSettings;

    if (settings?.posAuthenticateClearCart != true) {
      return true;
    }

    final expectedKey = settings?.posAuthenticateClearCartKey.trim() ?? '';
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PosSecurityKeyDialog(
        expectedKey: expectedKey,
        action: action,
      ),
    );
    return result == true;
  }
}

class _PosSecurityKeyDialog extends StatefulWidget {
  const _PosSecurityKeyDialog({
    required this.expectedKey,
    required this.action,
  });

  final String expectedKey;
  final String action;

  @override
  State<_PosSecurityKeyDialog> createState() => _PosSecurityKeyDialogState();
}

class _PosSecurityKeyDialogState extends State<_PosSecurityKeyDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  bool get _hasValidConfiguredKey =>
      RegExp(r'^\d{4}$').hasMatch(widget.expectedKey);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    final enteredKey = _controller.text.trim();

    if (!_hasValidConfiguredKey) {
      setState(() {
        _errorText = 'Security key is not configured correctly.';
      });
      return;
    }

    if (!RegExp(r'^\d{4}$').hasMatch(enteredKey)) {
      setState(() {
        _errorText = 'Enter the 4-digit security key.';
      });
      return;
    }

    if (enteredKey != widget.expectedKey) {
      setState(() {
        _errorText = 'Incorrect security key.';
      });
      _controller.clear();
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('pos_security_key_dialog'),
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: Color(0xFF2563EB)),
          SizedBox(width: 10),
          Expanded(child: Text('Security Key Required')),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter the 4-digit security key to ${widget.action}.'),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey(PosSecurityKeyDialog.inputKey),
              controller: _controller,
              autofocus: true,
              obscureText: true,
              obscuringCharacter: '•',
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              maxLength: 4,
              onSubmitted: (_) => _verify(),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: '4-digit security key',
                border: const OutlineInputBorder(),
                errorText: _errorText,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey(PosSecurityKeyDialog.cancelButtonKey),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('general.cancel'.tr),
        ),
        FilledButton(
          key: const ValueKey(PosSecurityKeyDialog.verifyButtonKey),
          onPressed: _verify,
          child: Text('general.verify'.tr),
        ),
      ],
    );
  }
}
