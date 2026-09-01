import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/services/common_print_settings.dart';

import 'printer_settings_responsive.dart';

/// One reusable margin control shared by every Printer Settings tab.
///
/// The setting is intentionally one all-sides value. It is persisted once,
/// then consumed by the common PDF renderer at print time. It only affects
/// standard PDF (A4/A5) output — thermal paper is fixed-width and printers
/// already reserve their own non-printable edge.
class CommonPrintMarginsCard extends StatefulWidget {
  /// When true the control renders without its own card chrome, so it can sit
  /// inside a parent card such as the advanced/shared options disclosure.
  final bool embedded;

  /// When false the slider is shown but not editable. The control stays on the
  /// page so the layout does not change shape between paper sizes; [disabledNote]
  /// explains why it is inactive.
  final bool enabled;
  final String? disabledNote;

  const CommonPrintMarginsCard({
    super.key,
    this.embedded = false,
    this.enabled = true,
    this.disabledNote,
  });

  @override
  State<CommonPrintMarginsCard> createState() => _CommonPrintMarginsCardState();
}

class _CommonPrintMarginsCardState extends State<CommonPrintMarginsCard> {
  double _marginMm = CommonPrintSettings.defaultMarginMm;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMargin();
  }

  Future<void> _loadMargin() async {
    try {
      final marginMm = await CommonPrintSettings.loadMarginMm();
      if (!mounted) return;
      setState(() {
        _marginMm = marginMm;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _updateMargin(double value) {
    setState(() {
      _marginMm = CommonPrintSettings.normalizeMarginMm(value);
    });
  }

  Future<void> _saveMargin(double value) async {
    try {
      await CommonPrintSettings.saveMarginMm(value);
    } catch (_) {
      // The print renderer will continue using the last persisted value.
      // Avoid interrupting slider interaction for a storage failure.
    }
  }

  Future<void> _resetMargin() async {
    _updateMargin(CommonPrintSettings.defaultMarginMm);
    await _saveMargin(CommonPrintSettings.defaultMarginMm);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = printerIsCompact(context);
    final cardPadding = printerCardPadding(context);
    final value = _marginMm.clamp(
      CommonPrintSettings.minMarginMm,
      CommonPrintSettings.maxMarginMm,
    );
    final isInteractive = widget.enabled && !_isLoading;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrinterSectionHeader(
          icon: Icons.border_all_rounded,
          title: 'Print Margins',
          subtitle: 'Safe area added to every edge of standard PDF pages',
          trailing: TextButton.icon(
            onPressed: isInteractive ? _resetMargin : null,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: ColorManager.kPrimaryColor,
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 4 : 8,
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12 : 16),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.toDouble(),
                min: CommonPrintSettings.minMarginMm,
                max: CommonPrintSettings.maxMarginMm,
                divisions: 20,
                label: '${value.toStringAsFixed(1)} mm',
                onChanged: isInteractive ? _updateMargin : null,
                onChangeEnd: isInteractive ? _saveMargin : null,
              ),
            ),
            SizedBox(width: isCompact ? 8 : 16),
            SizedBox(
              width: isCompact ? 58 : 72,
              child: Text(
                _isLoading ? 'Loading…' : '${value.toStringAsFixed(1)} mm',
                textAlign: TextAlign.end,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s13,
                  0.10,
                  ColorManager.kPrimaryColor,
                ),
              ),
            ),
          ],
        ),
        if (!widget.enabled && widget.disabledNote != null)
          Text(
            widget.disabledNote!,
            maxLines: 3,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.10,
              Colors.grey.shade600,
            ),
          ),
      ],
    );

    if (widget.embedded) return body;

    return PrinterSettingsCard(padding: cardPadding, child: body);
  }
}
