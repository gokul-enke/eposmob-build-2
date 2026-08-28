import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/services/common_print_settings.dart';

import 'printer_settings_responsive.dart';

/// Controls the media configuration used by standard A4/A5 PDF print jobs.
///
/// This setting is shared by the standard PDF printer tabs. Barcode printing
/// is not changed by this control because it has its own driver-specific path.
class CommonPrinterSettingsCard extends StatefulWidget {
  const CommonPrinterSettingsCard({super.key});

  @override
  State<CommonPrinterSettingsCard> createState() =>
      _CommonPrinterSettingsCardState();
}

class _CommonPrinterSettingsCardState extends State<CommonPrinterSettingsCard> {
  bool _usePrinterSettings = CommonPrintSettings.defaultUsePrinterSettings;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  Future<void> _loadSetting() async {
    try {
      final value = await CommonPrintSettings.loadUsePrinterSettings();
      if (!mounted) return;
      setState(() {
        _usePrinterSettings = value;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSetting(bool value) async {
    if (_isSaving) return;

    final previousValue = _usePrinterSettings;
    setState(() {
      _usePrinterSettings = value;
      _isSaving = true;
    });

    try {
      final saved = await CommonPrintSettings.saveUsePrinterSettings(value);
      if (!saved) throw StateError('Shared preferences write failed');
    } catch (_) {
      if (!mounted) return;
      setState(() => _usePrinterSettings = previousValue);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save printer setting')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resetSetting() async {
    await _updateSetting(CommonPrintSettings.defaultUsePrinterSettings);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = printerIsCompact(context);
    final cardPadding = printerCardPadding(context);

    return PrinterSettingsCard(
      padding: cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrinterSectionHeader(
            icon: Icons.settings_input_component_rounded,
            title: 'Use Printer Driver Settings',
            subtitle: 'Choose how standard A4/A5 PDFs are sent to Windows',
            trailing: TextButton.icon(
              onPressed: _isLoading || _isSaving ? null : _resetSetting,
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
          SizedBox(height: isCompact ? 8 : 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: isCompact,
            value: _usePrinterSettings,
            onChanged: _isLoading || _isSaving ? null : _updateSetting,
            title: Text(
              _usePrinterSettings
                  ? 'Use the selected printer’s saved media settings'
                  : 'Use the PDF’s selected A4/A5 page size',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s13,
                0.10,
                ColorManager.textColor,
              ),
            ),
            subtitle: Text(
              _usePrinterSettings
                  ? 'Enable only when the printer driver is configured for the exact document size.'
                  : 'Recommended for normal invoices because it preserves the PDF page size and helps prevent cropping.',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s11,
                0.10,
                Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            _isLoading
                ? 'Loading printer setting…'
                : 'This shared setting applies to standard PDF print jobs. Barcode printing keeps its dedicated driver setting.',
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
