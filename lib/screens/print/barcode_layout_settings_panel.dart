import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/models/barcode_layout_settings.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/widgets/printer_settings_responsive.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBarcodeLayoutSettingsKey = 'barcode_layout_settings';

/// Widget that shows barcode layout controls (scrollable left) and a live
/// preview + printer list (fixed right).
class BarcodeLayoutSettingsPanel extends StatefulWidget {
  /// Optional widget shown below the preview (e.g. available printer list).
  final Widget? printerListWidget;

  const BarcodeLayoutSettingsPanel({super.key, this.printerListWidget});

  @override
  State<BarcodeLayoutSettingsPanel> createState() =>
      _BarcodeLayoutSettingsPanelState();
}

class _BarcodeLayoutSettingsPanelState
    extends State<BarcodeLayoutSettingsPanel> {
  BarcodeLayoutSettings _settings = BarcodeLayoutSettings();
  bool _loaded = false;
  Future<void> _saveQueue = Future<void>.value();

  final List<String> _stickerSizes =
      BarcodeLayoutSettings.supportedStickerSizes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kBarcodeLayoutSettingsKey);
    if (raw != null) {
      try {
        _settings = BarcodeLayoutSettings.decode(raw);
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  void _save(BarcodeLayoutSettings settings) {
    final encoded = settings.encode();
    _saveQueue = _saveQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(kBarcodeLayoutSettingsKey, encoded);
      if (!saved) {
        throw StateError('Could not persist barcode layout settings');
      }
    }).catchError((Object error, StackTrace stackTrace) {
      debugPrint('[BarcodeSettings] Save failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('barcode_layout.toast_save_error'.tr)),
        );
      }
    });
  }

  void _update(BarcodeLayoutSettings Function(BarcodeLayoutSettings) fn) {
    final updated = fn(_settings);
    setState(() => _settings = updated);
    _save(updated);
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _settings = BarcodeLayoutSettings();
    });
    _save(_settings);
    await _saveQueue;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('barcode_layout.toast_reset_success'.tr),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isStacked = constraints.maxWidth < kPrinterPhoneBreakpoint;

        if (isStacked) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildControls(),
                const SizedBox(height: 16),
                _buildPreviewCard(),
                if (widget.printerListWidget != null) ...[
                  const SizedBox(height: 16),
                  widget.printerListWidget!,
                ],
              ],
            ),
          );
        }

        final controls = SingleChildScrollView(child: _buildControls());
        final previewColumn = SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPreviewCard(),
              if (widget.printerListWidget != null) ...[
                const SizedBox(height: 16),
                widget.printerListWidget!,
              ],
            ],
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: controls),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: previewColumn),
          ],
        );
      },
    );
  }

  Widget _buildControls() {
    final isCompact =
        MediaQuery.of(context).size.width < kPrinterPhoneBreakpoint;

    return PrinterSettingsCard(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrinterSectionHeader(
            icon: Icons.tune_rounded,
            title: 'barcode_layout.title'.tr,
            subtitle: 'barcode_layout.subtitle'.tr,
            trailing: SizedBox(
              height: 44,
              child: TextButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.restore, size: 18),
                label: Text('barcode_layout.btn_reset'.tr),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[600],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---- Sticker Size ----
          _sectionLabel('barcode_layout.label_sticker_size'.tr),
          const SizedBox(height: 8),
          _dropdownRow(
            value: _settings.stickerSize,
            items: _stickerSizes,
            onChanged: (v) => _update((s) => s.copyWith(stickerSize: v)),
          ),
          const SizedBox(height: 16),

          // ---- Stickers Per Row ----
          _sectionLabel('barcode_layout.label_stickers_per_row'.tr),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.stickersPerRow.toDouble(),
            min: 1,
            max: 3,
            divisions: 2,
            label: '${_settings.stickersPerRow}',
            onChanged: (v) =>
                _update((s) => s.copyWith(stickersPerRow: v.round())),
          ),
          const SizedBox(height: 16),

          // ---- Page Margin ----
          _sectionLabel('barcode_layout.label_page_margin'.tr),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.pageMargin,
            min: 0,
            max: 10,
            divisions: 20,
            label: '${_settings.pageMargin.toStringAsFixed(1)}mm',
            onChanged: (v) => _update((s) =>
                s.copyWith(pageMargin: double.parse(v.toStringAsFixed(1)))),
          ),
          const SizedBox(height: 16),

          // ---- Gap Between Stickers ----
          _sectionLabel('barcode_layout.label_gap_between'.tr),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.stickerGap,
            min: 0,
            max: 10,
            divisions: 20,
            label: '${_settings.stickerGap.toStringAsFixed(1)}mm',
            onChanged: (v) => _update((s) =>
                s.copyWith(stickerGap: double.parse(v.toStringAsFixed(1)))),
          ),
          const SizedBox(height: 16),

          // ---- Barcode Height ----
          _sectionLabel('barcode_layout.label_barcode_height'.tr),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.barcodeHeight,
            min: 5,
            max: 60,
            divisions: 55,
            label: '${_settings.barcodeHeight.round()}pt',
            onChanged: (v) =>
                _update((s) => s.copyWith(barcodeHeight: v.roundToDouble())),
          ),
          const SizedBox(height: 16),

          // ---- Barcode Width ----
          _sectionLabel('barcode_layout.label_barcode_width'.tr),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.barcodeWidthPercent,
            min: 30,
            max: 95,
            divisions: 65,
            label: '${_settings.barcodeWidthPercent.round()}%',
            onChanged: (v) => _update(
              (s) => s.copyWith(barcodeWidthPercent: v.roundToDouble()),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Raster DPI ----
          _sectionLabel('barcode_layout.label_printer_resolution'.tr),
          const SizedBox(height: 8),
          _dropdownRow(
            value: _settings.rasterDpi.toString(),
            items: const ['203', '300'],
            itemLabel: (value) => '$value DPI',
            onChanged: (v) =>
                _update((s) => s.copyWith(rasterDpi: int.parse(v))),
          ),
          const SizedBox(height: 16),

          // ---- PDF print rotation correction ----
          _sectionLabel('barcode_layout.label_rotation'.tr),
          const SizedBox(height: 8),
          _dropdownRow(
            value: _settings.printRotationDegrees?.toString() ?? 'default',
            items: const ['default', '90', '180', '270'],
            itemLabel: (value) =>
                value == 'default' ? 'barcode_layout.rotation_default'.tr : '$value°',
            onChanged: (v) => _update((s) => v == 'default'
                ? s.copyWith(usePrinterDefaultRotation: true)
                : s.copyWith(printRotationDegrees: int.parse(v))),
          ),
          const SizedBox(height: 6),
          Text(
            'barcode_layout.rotation_hint'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.10,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),

          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('barcode_layout.label_invert_colors'.tr),
              subtitle: Text('barcode_layout.invert_colors_hint'.tr),
              value: _settings.invertPrintColors,
              onChanged: (value) => _update(
                (s) => s.copyWith(invertPrintColors: value ?? false),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ---- Element Spacing ----
          _sectionLabel('barcode_layout.label_element_spacing'.tr),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.elementSpacing,
            min: 0,
            max: 8,
            divisions: 16,
            label: '${_settings.elementSpacing.toStringAsFixed(1)}pt',
            onChanged: (v) => _update((s) =>
                s.copyWith(elementSpacing: double.parse(v.toStringAsFixed(1)))),
          ),
          const SizedBox(height: 20),

          const Divider(),
          const SizedBox(height: 12),

          Text(
            'barcode_layout.font_sizes_title'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s14,
              0.18,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 16),

          _fontSizeRow(
            label: 'barcode_layout.font_store_name'.tr,
            value: _settings.storeNameFontSize,
            onChanged: (v) => _update((s) => s.copyWith(storeNameFontSize: v)),
          ),
          const SizedBox(height: 12),
          _fontSizeRow(
            label: 'barcode_layout.font_product_name'.tr,
            value: _settings.productNameFontSize,
            onChanged: (v) =>
                _update((s) => s.copyWith(productNameFontSize: v)),
          ),
          const SizedBox(height: 12),
          _fontSizeRow(
            label: 'barcode_layout.font_price'.tr,
            value: _settings.priceFontSize,
            onChanged: (v) => _update((s) => s.copyWith(priceFontSize: v)),
          ),
          const SizedBox(height: 12),
          _fontSizeRow(
            label: 'barcode_layout.font_date'.tr,
            value: _settings.dateFontSize,
            onChanged: (v) => _update((s) => s.copyWith(dateFontSize: v)),
          ),
          const SizedBox(height: 12),
          _fontSizeRow(
            label: 'barcode_layout.font_barcode_number'.tr,
            value: _settings.barcodeNumberFontSize,
            onChanged: (v) =>
                _update((s) => s.copyWith(barcodeNumberFontSize: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final isCompact =
        MediaQuery.of(context).size.width < kPrinterPhoneBreakpoint;

    return PrinterSettingsCard(
      padding: EdgeInsets.all(isCompact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PrinterSectionHeader(
            icon: Icons.preview_rounded,
            title: 'barcode_layout.preview_title'.tr,
            subtitle: 'barcode_layout.preview_subtitle'.tr,
          ),
          const SizedBox(height: 10),
          PrinterInfoStrip(
            text: 'barcode_layout.preview_strip'.trParams({
              'size': _settings.stickerSize,
              'count': '${_settings.stickersPerRow}',
              'barcode':
                  '${_settings.barcodeWidthPercent.round()}% × ${_settings.barcodeHeight.round()}pt',
              'dpi': '${_settings.rasterDpi}',
              'rotation': _settings.printRotationDegrees == null
                  ? 'barcode_layout.rotation_default'.tr
                  : '${_settings.printRotationDegrees}°',
              'inverted': _settings.invertPrintColors
                  ? 'barcode_layout.preview_inverted'.tr
                  : '',
            }),
            icon: Icons.straighten_rounded,
          ),
          const SizedBox(height: 20),
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: EdgeInsets.all(_settings.pageMargin * 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      _settings.stickersPerRow.clamp(1, 3),
                      (i) => Padding(
                        padding: EdgeInsets.only(
                          right: i < _settings.stickersPerRow.clamp(1, 3) - 1
                              ? _settings.stickerGap * 3
                              : 0,
                        ),
                        child: _buildStickerPreview(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'barcode_layout.preview_disclaimer'.tr,
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s10,
                0.10,
                Colors.grey.shade500,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerPreview() {
    // Scale factor: we want the 50mm sticker to display at ~200px wide
    const double scaleFactor = 200 / 50;
    final double previewW = _settings.stickerWidthMm * scaleFactor;
    final double previewH = _settings.stickerHeightMm * scaleFactor;
    final double barcodePreviewH = _settings.barcodeHeight * scaleFactor * 0.4;
    final double reservedBarcodePreviewH =
        (_settings.barcodeHeight < BarcodeLayoutSettings.defaultBarcodeHeight
                ? BarcodeLayoutSettings.defaultBarcodeHeight
                : _settings.barcodeHeight) *
            scaleFactor *
            0.4;

    // Font scale: relate to pt sizes (rough approximation)
    double fs(double pt) => (pt * scaleFactor * 0.45).clamp(6, 40);
    // Element spacing is stored in points; scaleFactor is px-per-mm.
    final spacing = _settings.elementSpacing / 2.83465 * scaleFactor;

    return Container(
      width: previewW,
      height: previewH,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[400]!, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: SizedBox(
          width: previewW - 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Store Name
              Text(
                'barcode_layout.sample_store'.tr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fs(_settings.storeNameFontSize),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacing),

              // Barcode representation
              SizedBox(
                height: reservedBarcodePreviewH,
                child: Center(
                  child: Container(
                    height: barcodePreviewH,
                    width: previewW *
                        (_settings.barcodeWidthPercent / 100).clamp(0.30, 0.95),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black54, width: 0.5),
                    ),
                    child: CustomPaint(
                      painter: _BarcodePlaceholderPainter(),
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing),

              // Barcode number
              Text(
                '12345678',
                style: TextStyle(
                  fontSize: fs(_settings.barcodeNumberFontSize),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing),

              // Product Name
              Text(
                'barcode_layout.sample_product'.tr,
                style: TextStyle(
                  fontSize: fs(_settings.productNameFontSize),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacing),

              // Price
              Text(
                'SAR 6.54',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fs(_settings.priceFontSize),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing),

              // Date line
              Text(
                'P:04/04/2026 E:03/04/2027',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fs(_settings.dateFontSize),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helper widgets ────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: buildCustomStyle(
        FontWeightManager.semiBold,
        FontSize.s12,
        0.15,
        ColorManager.textColor,
      ),
    );
  }

  Widget _dropdownRow({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String value)? itemLabel,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox(),
        items: items
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(itemLabel?.call(s) ?? s),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _sliderRow({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;

        final slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: ColorManager.kPrimaryColor,
            thumbColor: ColorManager.kPrimaryColor,
            overlayColor: ColorManager.kPrimaryColor.withValues(alpha: 0.15),
            inactiveTrackColor: Colors.grey[300],
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: label,
            onChanged: onChanged,
          ),
        );

        final valueLabel = Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
          textAlign: TextAlign.right,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              slider,
              Align(alignment: Alignment.centerRight, child: valueLabel),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: slider),
            SizedBox(width: 60, child: valueLabel),
          ],
        );
      },
    );
  }

  Widget _fontSizeRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 420;

        final labelWidget = Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.15,
            Colors.grey.shade700,
          ),
        );

        final slider = SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: ColorManager.kPrimaryColor,
            thumbColor: ColorManager.kPrimaryColor,
            overlayColor: ColorManager.kPrimaryColor.withValues(alpha: 0.15),
            inactiveTrackColor: Colors.grey[300],
          ),
          child: Slider(
            value: value.clamp(4, 24),
            min: 4,
            max: 24,
            divisions: 40,
            label: '${value.toStringAsFixed(1)}pt',
            onChanged: onChanged,
          ),
        );

        final valueLabel = Text(
          value.toStringAsFixed(1),
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
          textAlign: TextAlign.right,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              labelWidget,
              const SizedBox(height: 4),
              slider,
              Align(alignment: Alignment.centerRight, child: valueLabel),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 120, child: labelWidget),
            Expanded(child: slider),
            SizedBox(width: 50, child: valueLabel),
          ],
        );
      },
    );
  }
}

/// Paints simple barcode-like vertical lines as a placeholder.
class _BarcodePlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.2;

    // Draw alternating thick/thin bars
    double x = 2;
    int i = 0;
    while (x < size.width - 2) {
      final thick = (i % 3 == 0);
      final w = thick ? 2.0 : 1.0;
      canvas.drawRect(
        Rect.fromLTWH(x, 2, w, size.height - 4),
        paint,
      );
      x += w + (thick ? 2.5 : 1.5);
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper to load settings from SharedPreferences (for use in other files).
Future<BarcodeLayoutSettings> loadBarcodeLayoutSettings() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kBarcodeLayoutSettingsKey);
  if (raw != null) {
    try {
      return BarcodeLayoutSettings.decode(raw);
    } catch (_) {}
  }
  return BarcodeLayoutSettings();
}
