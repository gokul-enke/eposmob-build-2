import 'package:flutter/material.dart';
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

class ConfirmBarcodePrintModal extends StatefulWidget {
  final List<GetProduct> selectedProducts;

  const ConfirmBarcodePrintModal({super.key, required this.selectedProducts});

  @override
  _ConfirmBarcodePrintModalState createState() =>
      _ConfirmBarcodePrintModalState();
}

class _ConfirmBarcodePrintModalState extends State<ConfirmBarcodePrintModal> {
  late List<BarcodePrintItem> printItems;
  String stickerSize = '50x25mm';
  int stickersPerRow = 1;

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

  @override
  void initState() {
    super.initState();
    _applySavedLayoutDefaults();
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, now.day);

    printItems = widget.selectedProducts.map((product) {
      DateTime? expDateToUse = nextMonth;
      // Get expiry date from product stocks if available, otherwise any identifiable expiry field
      String? expiryDate;
      if (product.stock != null && product.stock!.isNotEmpty) {
        expiryDate = product.stock![0].expiryDate;
      }
      
      if (expiryDate != null && expiryDate.trim().isNotEmpty) {
        try {
          expDateToUse = DateTime.parse(expiryDate);
        } catch (e) {
          // Ignore failure, falls back to next month
        }
      }

      return BarcodePrintItem(
        product: product,
        quantity: 1,
        mfgDate: now,
        expDate: expDateToUse,
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
      _stickersPerRowController.text = stickersPerRow.toString();
    });
  }

  @override
  void dispose() {
    _stickersPerRowController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, int index, bool isMfg) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isMfg) {
          printItems[index].mfgDate = picked;
        } else {
          printItems[index].expDate = picked;
        }
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        width: size.width * 0.8,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Controls Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Sticker Size",
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.blue.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: stickerSize,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down),
                                    items: stickerSizes.map((String value) {
                                      return DropdownMenuItem<String>(
                                        value: value,
                                        child: Text(value),
                                      );
                                    }).toList(),
                                    onChanged: (newValue) {
                                      _userAdjustedLayout = true;
                                      setState(() {
                                        if (newValue != null)
                                          stickerSize = newValue;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Stickers Per Row",
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
                                child: TextFormField(
                                  controller: _stickersPerRowController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    _userAdjustedLayout = true;
                                    stickersPerRow = int.tryParse(val) ?? 1;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                                  item.quantity =
                                                      (int.tryParse(val) ?? 1)
                                                          .clamp(0,
                                                              _maxQuantityPerItem);
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                      final safeStickersPerRow =
                          stickersPerRow.clamp(1, _maxStickersPerRow);
                      Navigator.pop(context, {
                        'items': printItems,
                        'size': stickerSize,
                        'stickersPerRow': safeStickersPerRow,
                      });
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
