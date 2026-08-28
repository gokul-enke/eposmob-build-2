import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/services/common_print_settings.dart';

import 'printer_settings_responsive.dart';

/// One reusable margin control shared by every Printer Settings tab.
///
/// The setting is intentionally one all-sides value. It is persisted once,
/// then consumed by the common PDF and thermal renderers at print time.
class CommonPrintMarginsCard extends StatefulWidget {
  const CommonPrintMarginsCard({super.key});

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

    return PrinterSettingsCard(
      padding: cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrinterSectionHeader(
            icon: Icons.border_all_rounded,
            title: 'Common Print Margins',
            subtitle:
                'One safe-area setting shared by every printer and PDF tab',
            trailing: TextButton.icon(
              onPressed: _isLoading ? null : _resetMargin,
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
                  onChanged: _isLoading ? null : _updateMargin,
                  onChangeEnd: _isLoading ? null : _saveMargin,
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
          Text(
            'Adds the same margin to the left, right, top and bottom. '
            'Barcode stickers keep their dedicated Page Margin control.',
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.10,
              Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
