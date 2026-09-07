import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
  /// When true the control renders without its own card chrome, so it can sit
  /// inside a parent card such as the advanced/shared options disclosure.
  final bool embedded;

  /// When false the switch is shown but not editable. The control stays on the
  /// page so the layout does not change shape between paper sizes; [disabledNote]
  /// explains why it is inactive.
  final bool enabled;
  final String? disabledNote;

  const CommonPrinterSettingsCard({
    super.key,
    this.embedded = false,
    this.enabled = true,
    this.disabledNote,
  });

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

    final isInteractive = widget.enabled && !_isLoading && !_isSaving;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrinterSectionHeader(
          icon: Icons.settings_input_component_rounded,
          title: 'printer_settings.driver_settings'.tr,
          subtitle: 'printer_settings.driver_settings_sub'.tr,
          trailing: TextButton.icon(
            onPressed: isInteractive ? _resetSetting : null,
            icon: const Icon(Icons.restore, size: 18),
            label: Text('general.reset'.tr),
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
          onChanged: isInteractive ? _updateSetting : null,
          title: Text(
            _usePrinterSettings
                ? 'printer_settings.use_printer_media'.tr
                : 'printer_settings.use_pdf_page_size'.tr,
            // buildCustomStyle bakes in TextOverflow.ellipsis, which clips to a
            // single line unless maxLines is given explicitly.
            maxLines: 2,
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
            maxLines: 3,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s11,
              0.10,
              Colors.grey.shade600,
            ),
          ),
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
