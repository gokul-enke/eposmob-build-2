import 'package:flutter/material.dart';
import 'package:pos_machine/models/barcode_layout_settings.dart';
import 'package:pos_machine/resources/color_manager.dart';
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

  final List<String> _stickerSizes = [
    '50x25mm',
    '30x20mm',
    '38x25mm',
    '40x25mm',
    '55x35mm',
    '60x40mm',
    '70x40mm',
    '100x50mm',
    '40x20mm',
    '91x24mm'
  ];

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
    setState(() => _loaded = true);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kBarcodeLayoutSettingsKey, _settings.encode());
  }

  void _update(BarcodeLayoutSettings Function(BarcodeLayoutSettings) fn) {
    setState(() {
      _settings = fn(_settings);
    });
    _save();
  }

  Future<void> _resetDefaults() async {
    setState(() {
      _settings = BarcodeLayoutSettings();
    });
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barcode layout reset to defaults'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Controls (scrollable)
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: _buildControls(),
          ),
        ),
        const SizedBox(width: 24),
        // Right: Preview + Printer list (fixed)
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPreviewCard(),
                if (widget.printerListWidget != null) ...[
                  const SizedBox(height: 24),
                  widget.printerListWidget!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded,
                    color: ColorManager.kPrimaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Barcode Sticker Layout',
                  style: TextStyle(
                    color: ColorManager.kPrimaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---- Sticker Size ----
          _sectionLabel('Sticker Size'),
          const SizedBox(height: 8),
          _dropdownRow(
            value: _settings.stickerSize,
            items: _stickerSizes,
            onChanged: (v) => _update((s) => s.copyWith(stickerSize: v)),
          ),
          const SizedBox(height: 16),

          // ---- Stickers Per Row ----
          _sectionLabel('Stickers Per Row'),
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
          _sectionLabel('Page Margin (mm)'),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.pageMargin,
            min: 0,
            max: 10,
            divisions: 20,
            label: '${_settings.pageMargin.toStringAsFixed(1)}mm',
            onChanged: (v) => _update(
                (s) => s.copyWith(pageMargin: double.parse(v.toStringAsFixed(1)))),
          ),
          const SizedBox(height: 16),

          // ---- Gap Between Stickers ----
          _sectionLabel('Gap Between Stickers (mm)'),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.stickerGap,
            min: 0,
            max: 10,
            divisions: 20,
            label: '${_settings.stickerGap.toStringAsFixed(1)}mm',
            onChanged: (v) => _update(
                (s) => s.copyWith(stickerGap: double.parse(v.toStringAsFixed(1)))),
          ),
          const SizedBox(height: 16),

          // ---- Barcode Height ----
          _sectionLabel('Barcode Height (pt)'),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.barcodeHeight,
            min: 15,
            max: 60,
            divisions: 45,
            label: '${_settings.barcodeHeight.round()}pt',
            onChanged: (v) =>
                _update((s) => s.copyWith(barcodeHeight: v.roundToDouble())),
          ),
          const SizedBox(height: 16),

          // ---- Element Spacing ----
          _sectionLabel('Element Spacing (pt)'),
          const SizedBox(height: 8),
          _sliderRow(
            value: _settings.elementSpacing,
            min: 0,
            max: 8,
            divisions: 16,
            label: '${_settings.elementSpacing.toStringAsFixed(1)}pt',
            onChanged: (v) => _update(
                (s) => s.copyWith(elementSpacing: double.parse(v.toStringAsFixed(1)))),
          ),
          const SizedBox(height: 20),

          const Divider(),
          const SizedBox(height: 12),

          // ---- Font Sizes ----
          const Text(
            'Font Sizes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ColorManager.kTitleTextColor,
            ),
          ),
          const SizedBox(height: 16),

          _fontSizeRow(
            label: 'Store Name',
            value: _settings.storeNameFontSize,
            onChanged: (v) =>
                _update((s) => s.copyWith(storeNameFontSize: v)),
          ),
          const SizedBox(height: 12),
          _fontSizeRow(
            label: 'Product Name',
            value: _settings.productNameFontSize,
            onChanged: (v) =>
                _update((s) => s.copyWith(productNameFontSize: v)),
          ),
          const SizedBox(height: 12),
          _fontSizeRow(
            label: 'Price',
            value: _settings.priceFontSize,
            onChanged: (v) => _update((s) => s.copyWith(priceFontSize: v)),
          ),
          const SizedBox(height: 12),
          _fontSizeRow(
            label: 'Date',
            value: _settings.dateFontSize,
            onChanged: (v) => _update((s) => s.copyWith(dateFontSize: v)),
          ),
          const SizedBox(height: 12),
          _fontSizeRow(
            label: 'Barcode Number',
            value: _settings.barcodeNumberFontSize,
            onChanged: (v) =>
                _update((s) => s.copyWith(barcodeNumberFontSize: v)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ColorManager.kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.preview_rounded,
                    color: ColorManager.kPrimaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Sticker Preview',
                style: TextStyle(
                  color: ColorManager.kPrimaryColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Size: ${_settings.stickerSize}  ·  ${_settings.stickersPerRow} per row  ·  Margin: ${_settings.pageMargin.toStringAsFixed(1)}mm  ·  Gap: ${_settings.stickerGap.toStringAsFixed(1)}mm',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 20),

          // Preview area
          Center(
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
          const SizedBox(height: 16),
          Center(
            child: Text(
              'This is an approximate preview. Actual PDF output may vary.',
              style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
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

    // Font scale: relate to pt sizes (rough approximation)
    double fs(double pt) => (pt * scaleFactor * 0.45).clamp(6, 40);
    final spacing = _settings.elementSpacing * scaleFactor * 0.4;

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
                'STORE NAME',
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
              Container(
                height: _settings.barcodeHeight * scaleFactor * 0.4,
                width: previewW * 0.7,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black54, width: 0.5),
                ),
                child: CustomPaint(
                  painter: _BarcodePlaceholderPainter(),
                  size: Size(previewW * 0.7,
                      _settings.barcodeHeight * scaleFactor * 0.4),
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

              // Product Name
              Text(
                'Sample Product',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fs(_settings.productNameFontSize),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: spacing),

              // Date line
              Text(
                'PKG:04-04-26 EXD:03-04-27',
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
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ColorManager.kTitleTextColor,
      ),
    );
  }

  Widget _dropdownRow({
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
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
            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
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
          ),
        ),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _fontSizeRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
        ),
        Expanded(
          child: SliderTheme(
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
          ),
        ),
        SizedBox(
          width: 50,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            textAlign: TextAlign.right,
          ),
        ),
      ],
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
