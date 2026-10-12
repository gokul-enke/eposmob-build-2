import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';

class LocalSaleRequestEditor extends StatefulWidget {
  const LocalSaleRequestEditor({
    super.key,
    required this.orderNumber,
    required this.payload,
    required this.onSave,
  });

  final String orderNumber;
  final Map<String, dynamic> payload;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<LocalSaleRequestEditor> createState() => _LocalSaleRequestEditorState();
}

class _LocalSaleRequestEditorState extends State<LocalSaleRequestEditor> {
  static const _encoder = JsonEncoder.withIndent('  ');
  late final _text =
      TextEditingController(text: _encoder.convert(widget.payload));
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _parse() {
    try {
      final decoded = jsonDecode(_text.text);
      if (decoded is! Map<String, dynamic> || decoded.isEmpty) {
        setState(() => _error =
            'Enter a non-empty JSON object, such as {"order_id": 123}.');
        return null;
      }
      setState(() => _error = null);
      return decoded;
    } on FormatException catch (error) {
      final offset = error.offset;
      final line = offset == null
          ? null
          : '\n'.allMatches(_text.text.substring(0, offset)).length + 1;
      setState(() => _error =
          'Invalid JSON${line == null ? '' : ' on line $line'}: ${error.message}');
      return null;
    }
  }

  Future<void> _save() async {
    final payload = _parse();
    if (payload == null) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(payload);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is StateError
            ? error.message.toString()
            : 'Could not save the request. Your changes are still here; try again.';
      });
    }
  }

  void _format() {
    final payload = _parse();
    if (payload != null) {
      _text.text = _encoder.convert(payload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 600;
    final content = LayoutBuilder(builder: (context, constraints) {
      final short = constraints.maxHeight < 460;
      return Padding(
        padding: EdgeInsets.all(short
            ? 8
            : compact
                ? 16
                : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.data_object, color: Color(0xFF0F3D75)),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Edit request JSON',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w600))),
              IconButton(
                  key: const ValueKey('request-editor-close'),
                  tooltip: 'Cancel editing',
                  onPressed:
                      _saving ? null : () => Navigator.of(context).pop(false),
                  icon: const Icon(Icons.close)),
            ]),
            if (!short)
              Text('Order #${widget.orderNumber}',
                  style:
                      const TextStyle(color: Color(0xFF475569), fontSize: 14)),
            SizedBox(height: short ? 6 : 12),
            if (!short)
              const Text(
                  'Edit IDs, dates or other request fields. Save stores the next request on this device. Use Sync to send it. Past attempts and the saved receipt stay unchanged.',
                  style: TextStyle(
                      color: Color(0xFF475569), fontSize: 13, height: 1.45)),
            SizedBox(height: short ? 6 : 12),
            Expanded(
              child: TextField(
                key: const ValueKey('sale-request-json'),
                controller: _text,
                readOnly: _saving,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 14, height: 1.5),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: short ? 36 : 90),
                  child: SingleChildScrollView(
                      child: Text(_error!,
                          key: const ValueKey('request-json-error'),
                          style: const TextStyle(
                              color: Color(0xFFB42318), fontSize: 13)))),
            ],
            SizedBox(height: short ? 6 : 12),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  if (short)
                    IconButton(
                        key: const ValueKey('format-request-json'),
                        tooltip: 'Format JSON',
                        onPressed: _saving ? null : _format,
                        icon: const Icon(Icons.format_align_left))
                  else
                    TextButton.icon(
                        key: const ValueKey('format-request-json'),
                        onPressed: _saving ? null : _format,
                        icon: const Icon(Icons.format_align_left, size: 18),
                        label: const Text('Format JSON')),
                  if (!short)
                    TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel')),
                  FilledButton.icon(
                      key: const ValueKey('save-request-json'),
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: Text(_saving ? 'Saving…' : 'Save changes'),
                      style: FilledButton.styleFrom(
                          backgroundColor: ColorManager.kPrimaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44))),
                ]),
          ],
        ),
      );
    });
    return PopScope(
      canPop: !_saving,
      child: compact
          ? Dialog.fullscreen(child: SafeArea(child: content))
          : Dialog(
              insetPadding: const EdgeInsets.all(24),
              child: SizedBox(
                  width: 900,
                  height: math.min(760, size.height - 48),
                  child: content)),
    );
  }
}
