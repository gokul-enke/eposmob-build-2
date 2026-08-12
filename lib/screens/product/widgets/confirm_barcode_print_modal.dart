import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/print/barcode_layout_settings_panel.dart';

class BarcodePrintItem {
  final GetProduct product;
  int quantity;
  DateTime? mfgDate;
  DateTime? expDate;

  BarcodePrintItem({
    required this.product,
    this.quantity = 1,
    this.mfgDate,
    this.expDate,
  });
}

class BarcodePrintRequest {
  final List<BarcodePrintItem> items;
  final String stickerSize;
  final int stickersPerRow;
  final int printRotationDegrees;

  const BarcodePrintRequest({
    required this.items,
    required this.stickerSize,
    required this.stickersPerRow,
    this.printRotationDegrees = 0,
  });
}

class ConfirmBarcodePrintModal extends StatefulWidget {
  final List<GetProduct> selectedProducts;

  const ConfirmBarcodePrintModal({super.key, required this.selectedProducts});

  @override
  State<ConfirmBarcodePrintModal> createState() =>
      _ConfirmBarcodePrintModalState();
}

class _ConfirmBarcodePrintModalState extends State<ConfirmBarcodePrintModal> {
  late List<BarcodePrintItem> printItems;
  String stickerSize = '50x25mm';
  int stickersPerRow = 1;
  int printRotationDegrees = 0;

  /// Hard cap for the free-text per-row field; the settings slider only goes
  /// to 3, but typed input and saved JSON must not produce meter-wide pages.
  static const int _maxStickersPerRow = 10;

  /// Per-item quantity cap so a typo can't queue a multi-thousand-page PDF.
  static const int _maxQuantityPerItem = 999;

  // Once the user touches size or per-row, the async settings seed must not
  // overwrite their input.
  bool _userAdjustedLayout = false;

  final TextEditingController _stickersPerRowController =
      TextEditingController(text: '1');

  final List<String> stickerSizes = [
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

  DateTime? _tryParseProductDate(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    for (final pattern in const ['dd/MM/yyyy', 'dd-MM-yyyy', 'yyyy/MM/dd']) {
      try {
        return DateFormat(pattern).parseStrict(value);
      } catch (_) {}
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _applySavedLayoutDefaults();

    printItems = widget.selectedProducts.map((product) {
      // Only prefill dates when there is exactly one unambiguous stock batch.
      // Multiple batches require an explicit user choice; inventing or taking
      // stock[0] can put legally incorrect dates on a product label.
      final stock = product.stock?.length == 1 ? product.stock!.single : null;

      return BarcodePrintItem(
        product: product,
        quantity: 1,
        mfgDate: _tryParseProductDate(stock?.pkgMfg),
        expDate: _tryParseProductDate(stock?.expiryDate),
      );
    }).toList();
  }

  /// Seeds the sticker size and stickers-per-row from Printer Settings, so this
  /// modal starts at the configured layout. Both stay editable as a per-print
  /// override and are not written back.
  Future<void> _applySavedLayoutDefaults() async {
    final settings = await loadBarcodeLayoutSettings();
    if (!mounted || _userAdjustedLayout) return;

    setState(() {
      if (stickerSizes.contains(settings.stickerSize)) {
        stickerSize = settings.stickerSize;
      }
      stickersPerRow = settings.stickersPerRow.clamp(1, _maxStickersPerRow);
      printRotationDegrees = settings.printRotationDegrees;
      _stickersPerRowController.text = stickersPerRow.toString();
    });
  }

  @override
  void dispose() {
    _stickersPerRowController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, int index, bool isMfg) async {
    final current =
        isMfg ? printItems[index].mfgDate : printItems[index].expDate;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isMfg) {
          printItems[index].mfgDate = picked;
        } else {
          printItems[index].expDate = picked;
        }
      });
    }
  }

  bool _validateBeforeConfirm() {
    if (!printItems.any((item) => item.quantity > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter a quantity for at least one item.')),
      );
      return false;
    }
    for (final item in printItems) {
      final mfg = item.mfgDate;
      final exp = item.expDate;
      if (mfg != null && exp != null && exp.isBefore(mfg)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Expiry date cannot be before manufacturing date for ${item.product.productName ?? 'a product'}.',
            ),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Text(
        text,
        textAlign: TextAlign.left,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s12,
          0.18,
          Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildStickerSizeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sticker Size',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: stickerSize,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: stickerSizes
                  .map((value) =>
                      DropdownMenuItem(value: value, child: Text(value)))
                  .toList(),
              onChanged: (newValue) {
                if (newValue == null) return;
                _userAdjustedLayout = true;
                setState(() => stickerSize = newValue);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickersPerRowField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stickers Per Row',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 45,
          child: TextFormField(
            controller: _stickersPerRowController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (value) {
              _userAdjustedLayout = true;
              stickersPerRow = int.tryParse(value) ?? 1;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRotationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Print Rotation',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.2,
            Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: printRotationDegrees,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down),
              items: const [0, 90, 270]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value == 0 ? 'None (0°)' : '$value°'),
                    ),
                  )
                  .toList(),
              onChanged: (newValue) {
                if (newValue == null) return;
                _userAdjustedLayout = true;
                setState(() => printRotationDegrees = newValue);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        width: isCompact ? size.width * 0.96 : size.width * 0.8,
        constraints:
            BoxConstraints(maxWidth: 900, maxHeight: size.height * 0.85),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 16 : 24,
                vertical: 16,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFD32F2F), // Red header like in screenshot
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orangeAccent, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    "Confirm Barcode Print",
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s18,
                      0.5,
                      Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 12 : 24),
                child: Column(
                  children: [
                    if (isCompact) ...[
                      _buildStickerSizeField(),
                      const SizedBox(height: 12),
                      _buildStickersPerRowField(),
                      const SizedBox(height: 12),
                      _buildRotationField(),
                    ] else
                      Row(
                        children: [
                          Expanded(child: _buildStickerSizeField()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildStickersPerRowField()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildRotationField()),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Table
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            // Table Header
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                      flex: 3,
                                      child: _buildTableHeader("PRODUCT")),
                                  Expanded(
                                      flex: 1,
                                      child: _buildTableHeader("QUANTITY")),
                                  Expanded(
                                      flex: 1,
                                      child: _buildTableHeader("MFG DATE")),
                                  Expanded(
                                      flex: 1,
                                      child: _buildTableHeader("EXP DATE")),
                                ],
                              ),
                            ),
                            // Table Body
                            Expanded(
                              child: ListView.separated(
                                itemCount: printItems.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final item = printItems[index];
                                  final mfgStr = item.mfgDate != null
                                      ? DateFormat('yyyy-MM-dd')
                                          .format(item.mfgDate!)
                                      : "Select Date";
                                  final expStr = item.expDate != null
                                      ? DateFormat('yyyy-MM-dd')
                                          .format(item.expDate!)
                                      : "Select Date";

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0, horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(
                                            item.product.productName ?? 'N/A',
                                            style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s13,
                                                0.2,
                                                ColorManager.textColor),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: SizedBox(
                                            height: 35,
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                  right: 16.0),
                                              child: TextFormField(
                                                initialValue:
                                                    item.quantity.toString(),
                                                keyboardType:
                                                    TextInputType.number,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter
                                                      .digitsOnly,
                                                ],
                                                textAlign: TextAlign.center,
                                                decoration:
                                                    const InputDecoration(
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  border: OutlineInputBorder(),
                                                ),
                                                onChanged: (val) {
                                                  // 0 skips this product at
                                                  // print time; negatives are
                                                  // treated the same.
                                                  item.quantity = (int.tryParse(
                                                              val) ??
                                                          1)
                                                      .clamp(0,
                                                          _maxQuantityPerItem)
                                                      .toInt();
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: InkWell(
                                            onTap: () => _selectDate(
                                                context, index, true),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 4),
                                              child: Text(mfgStr,
                                                  style: TextStyle(
                                                      color:
                                                          item.mfgDate == null
                                                              ? Colors.grey
                                                              : Colors.black)),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: InkWell(
                                            onTap: () => _selectDate(
                                                context, index, false),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                      horizontal: 4),
                                              child: Text(expStr,
                                                  style: TextStyle(
                                                      color:
                                                          item.expDate == null
                                                              ? Colors.grey
                                                              : Colors.black)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 24,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomRoundButton(
                    title: "Cancel",
                    boxColor: const Color(0xFFD32F2F),
                    textColor: Colors.white,
                    borderColor: const Color(0xFFD32F2F),
                    fct: () => Navigator.pop(context),
                    height: 40,
                    width: 100,
                    fontSize: FontSize.s14,
                  ),
                  const SizedBox(width: 12),
                  CustomRoundButton(
                    title: "Confirm",
                    boxColor: const Color(0xFF2962FF),
                    textColor: Colors.white,
                    borderColor: const Color(0xFF2962FF),
                    fct: () {
                      if (!_validateBeforeConfirm()) return;
                      final safeStickersPerRow =
                          stickersPerRow.clamp(1, _maxStickersPerRow).toInt();
                      Navigator.pop(
                        context,
                        BarcodePrintRequest(
                          items: printItems,
                          stickerSize: stickerSize,
                          stickersPerRow: safeStickersPerRow,
                          printRotationDegrees: printRotationDegrees,
                        ),
                      );
                    },
                    height: 40,
                    width: 100,
                    fontSize: FontSize.s14,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
