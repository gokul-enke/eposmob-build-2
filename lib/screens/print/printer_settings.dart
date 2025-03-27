import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'dart:convert';

class BluetoothPrinter {
  String? deviceName;
  String? address;
  String? port;
  String? vendorId;
  String? productId;
  String typePrinter;
  bool isConnected;

  BluetoothPrinter({
    this.deviceName,
    this.address,
    this.port,
    this.vendorId,
    this.productId,
    required this.typePrinter,
    this.isConnected = false,
  });
}

class ReceiptSettings {
  // Store Header settings
  bool showStoreName;
  bool showTel;
  bool showEmail;
  bool showInvoiceNumber;

  // Date Header settings
  bool showDateHeader;

  // Cart Items settings
  bool showParticulars;
  bool showMRP;
  bool showQty;
  bool showRate;
  bool showTotal;

  // Amount Section settings
  bool showDiscount;
  bool showNetAmount;
  bool showMRPTotal;
  bool showSaved;

  // Additional settings
  bool showThankYouMessage;
  bool showQRCode;

  ReceiptSettings({
    this.showStoreName = true,
    this.showTel = true,
    this.showEmail = true,
    this.showInvoiceNumber = true,
    this.showDateHeader = true,
    this.showParticulars = true,
    this.showMRP = true,
    this.showQty = true,
    this.showRate = true,
    this.showTotal = true,
    this.showDiscount = true,
    this.showNetAmount = true,
    this.showMRPTotal = true,
    this.showSaved = true,
    this.showThankYouMessage = true,
    this.showQRCode = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'showStoreName': showStoreName,
      'showTel': showTel,
      'showEmail': showEmail,
      'showInvoiceNumber': showInvoiceNumber,
      'showDateHeader': showDateHeader,
      'showParticulars': showParticulars,
      'showMRP': showMRP,
      'showQty': showQty,
      'showRate': showRate,
      'showTotal': showTotal,
      'showDiscount': showDiscount,
      'showNetAmount': showNetAmount,
      'showMRPTotal': showMRPTotal,
      'showSaved': showSaved,
      'showThankYouMessage': showThankYouMessage,
      'showQRCode': showQRCode,
    };
  }

  factory ReceiptSettings.fromJson(Map<String, dynamic> json) {
    return ReceiptSettings(
      showStoreName: json['showStoreName'] ?? true,
      showTel: json['showTel'] ?? true,
      showEmail: json['showEmail'] ?? true,
      showInvoiceNumber: json['showInvoiceNumber'] ?? true,
      showDateHeader: json['showDateHeader'] ?? true,
      showParticulars: json['showParticulars'] ?? true,
      showMRP: json['showMRP'] ?? true,
      showQty: json['showQty'] ?? true,
      showRate: json['showRate'] ?? true,
      showTotal: json['showTotal'] ?? true,
      showDiscount: json['showDiscount'] ?? true,
      showNetAmount: json['showNetAmount'] ?? true,
      showMRPTotal: json['showMRPTotal'] ?? true,
      showSaved: json['showSaved'] ?? true,
      showThankYouMessage: json['showThankYouMessage'] ?? true,
      showQRCode: json['showQRCode'] ?? true,
    );
  }
}

class ReceiptTemplate {
  String id; // Unique identifier
  String name;
  ReceiptSettings settings;
  bool isDefault;

  ReceiptTemplate({
    String? id,
    required this.name,
    required this.settings,
    this.isDefault = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'settings': settings.toJson(),
      'isDefault': isDefault,
    };
  }

  factory ReceiptTemplate.fromJson(Map<String, dynamic> json) {
    return ReceiptTemplate(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'Unnamed Template',
      settings: ReceiptSettings.fromJson(json['settings']),
      isDefault: json['isDefault'] ?? false,
    );
  }

  ReceiptTemplate copyWith({
    String? id,
    String? name,
    ReceiptSettings? settings,
    bool? isDefault,
  }) {
    return ReceiptTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      settings: settings ?? this.settings,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class PrinterSettings extends StatefulWidget {
  const PrinterSettings({super.key});

  @override
  State<PrinterSettings> createState() => _PrinterSettingsState();
}

class _PrinterSettingsState extends State<PrinterSettings> {
  BluetoothPrinter? selectedPrinter;
  List<ReceiptTemplate> templates = [];
  ReceiptTemplate? selectedTemplate;
  bool isLoading = true;
  bool isEditing = false;
  final ScrollController _templatesScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _templatesScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final defaultPrinterJson = prefs.getString('default_printer');
    final templatesJson = prefs.getString('receipt_templates');

    if (defaultPrinterJson != null) {
      final Map<String, dynamic> printerData = json.decode(defaultPrinterJson);
      setState(() {
        selectedPrinter = BluetoothPrinter(
          deviceName: printerData['deviceName'],
          address: printerData['address'],
          vendorId: printerData['vendorId'],
          productId: printerData['productId'],
          typePrinter: printerData['typePrinter'],
        );
      });
    }

    if (templatesJson != null) {
      try {
        final List<dynamic> decodedData = json.decode(templatesJson);
        final List<ReceiptTemplate> loadedTemplates = decodedData
            .map((template) => ReceiptTemplate.fromJson(template))
            .toList();

        setState(() {
          templates = loadedTemplates;

          // Find default template
          final defaultTemplate = templates.firstWhere(
            (template) => template.isDefault,
            orElse: () => templates.isNotEmpty
                ? templates.first
                : ReceiptTemplate(
                    name: 'Default Template',
                    settings: ReceiptSettings(),
                    isDefault: true,
                  ),
          );

          // If no templates were loaded, create a default one
          if (templates.isEmpty) {
            templates.add(defaultTemplate);
          }

          selectedTemplate = defaultTemplate;
        });
      } catch (e) {
        print('Error decoding templates: $e');
        // Create a default template if none exists
        setState(() {
          templates = [
            ReceiptTemplate(
              name: 'Default Template',
              settings: ReceiptSettings(),
              isDefault: true,
            )
          ];
          selectedTemplate = templates.first;
        });
      }
    } else {
      // Create a default template if none exists
      setState(() {
        templates = [
          ReceiptTemplate(
            name: 'Default Template',
            settings: ReceiptSettings(),
            isDefault: true,
          )
        ];
        selectedTemplate = templates.first;
      });
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveTemplates({bool showMessage = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('receipt_templates',
          json.encode(templates.map((t) => t.toJson()).toList()));

      if (mounted && showMessage) {
        showScaffold(
          context: context,
          message: "Templates saved successfully",
        );
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error saving templates: ${e.toString()}",
        );
      }
    }
  }

  void _updateSelectedTemplateSettings(ReceiptSettings newSettings) {
    if (selectedTemplate != null) {
      setState(() {
        final index = templates.indexWhere((t) => t.id == selectedTemplate!.id);
        if (index != -1) {
          templates[index] = templates[index].copyWith(settings: newSettings);
          selectedTemplate = templates[index];
        }
      });

      // Automatically save template changes
      _saveTemplates(showMessage: false);
    }
  }

  void _createNewTemplate() {
    final newTemplate = ReceiptTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Template ${templates.length + 1}',
      settings: ReceiptSettings(),
      isDefault: false,
    );

    setState(() {
      templates.add(newTemplate);
      selectedTemplate = newTemplate;
      isEditing = true;
    });

    _saveTemplates();
  }

  void _setDefaultTemplate(ReceiptTemplate template) {
    setState(() {
      for (int i = 0; i < templates.length; i++) {
        templates[i] =
            templates[i].copyWith(isDefault: templates[i].id == template.id);
      }

      final index = templates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        selectedTemplate = templates[index];
      }
    });

    _saveTemplates();
  }

  void _deleteTemplate(ReceiptTemplate template) {
    if (templates.length <= 1) {
      showScaffoldError(
        context: context,
        message: "Cannot delete the only template",
      );
      return;
    }

    setState(() {
      templates.removeWhere((t) => t.id == template.id);

      // If the default template was deleted, set a new default
      if (template.isDefault && templates.isNotEmpty) {
        templates[0] = templates[0].copyWith(isDefault: true);
      }

      // Clear the selected template if the deleted template was selected
      if (selectedTemplate?.id == template.id) {
        selectedTemplate = null;
        isEditing = false;
      }
    });

    _saveTemplates();
  }

  void _renameTemplate(ReceiptTemplate template, String newName) {
    if (newName.isEmpty) return;

    setState(() {
      final index = templates.indexWhere((t) => t.id == template.id);
      if (index != -1) {
        templates[index] = templates[index].copyWith(name: newName);
        if (selectedTemplate?.id == template.id) {
          selectedTemplate = templates[index];
        }
      }
    });

    _saveTemplates();
  }

  Future<void> clearDefaultPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('default_printer');

      setState(() {
        selectedPrinter = null;
      });

      if (mounted) {
        showScaffold(
          context: context,
          message: "Default printer cleared successfully",
        );
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error clearing default printer: ${e.toString()}",
        );
      }
    }
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return BuildBoxShadowContainer(
      circleRadius: 7,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ColorManager.kPrimaryColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
      String title, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: 12,
            ),
          ),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: ColorManager.kPrimaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptPreview() {
    if (selectedTemplate == null) return const SizedBox();

    final settings = selectedTemplate!.settings;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      width: 300,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Store Header
            if (settings.showStoreName)
              const Text(
                'STORE NAME',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            if (settings.showTel)
              const Text(
                'TEL: 123-456-7890',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showEmail)
              const Text(
                'Email: example@store.com',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showInvoiceNumber)
              const Text(
                'INVOICE #12345',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            const Divider(),

            // Date Header
            if (settings.showDateHeader)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '2023-06-15',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '10:30 AM',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

            if (settings.showDateHeader) const Divider(),

            // Cart Items Table Header
            if (_anyCartColumnVisible())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    if (settings.showParticulars)
                      const Expanded(
                        flex: 4,
                        child: Text(
                          'PARTICULARS',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (settings.showMRP)
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'MRP',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    if (settings.showQty)
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'QTY',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    if (settings.showRate)
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'RATE',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    if (settings.showTotal)
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'TOTAL',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ),

            // Sample Cart Items
            if (_anyCartColumnVisible())
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 3,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        if (settings.showParticulars)
                          Expanded(
                            flex: 4,
                            child: Text(
                              'Item ${index + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        if (settings.showMRP)
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${100.0 + index * 5}',
                              style: const TextStyle(fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        if (settings.showQty)
                          const Expanded(
                            flex: 2,
                            child: Text(
                              '1',
                              style: TextStyle(fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        if (settings.showRate)
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${95.0 + index * 5}',
                              style: const TextStyle(fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        if (settings.showTotal)
                          Expanded(
                            flex: 2,
                            child: Text(
                              '${95.0 + index * 5}',
                              style: const TextStyle(fontSize: 11),
                              textAlign: TextAlign.right,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),

            if (_anyCartColumnVisible()) const Divider(),

            // Amount Section
            if (settings.showDiscount)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'DISCOUNT',
                    style: TextStyle(fontSize: 11),
                  ),
                  Text(
                    '0.00',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),

            if (settings.showNetAmount)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Net Amount',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '300.00',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            if (settings.showMRPTotal || settings.showSaved) const Divider(),

            if (settings.showMRPTotal)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Items 3',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'MRP TOTAL 315.00',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

            if (settings.showSaved)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'You Save',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '15.00',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

            const Divider(),

            // Thank You Message
            if (settings.showThankYouMessage)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Thank You... Visit Again',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // QR Code
            if (settings.showQRCode) ...[
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black),
                ),
                child: const Center(
                  child: Text(
                    'QR Code',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Scan this QR code to Pay',
                style: TextStyle(fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _anyCartColumnVisible() {
    if (selectedTemplate == null) return false;
    final settings = selectedTemplate!.settings;

    return settings.showParticulars ||
        settings.showMRP ||
        settings.showQty ||
        settings.showRate ||
        settings.showTotal;
  }

  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required Color color,
    bool isOutlined = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.white : color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isOutlined ? color : Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: isOutlined ? color : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: BuildBoxShadowContainer(
                circleRadius: 16,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.print_rounded,
                                  color: ColorManager.kPrimaryColor,
                                  size: 24,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Receipt Customization',
                                  style: TextStyle(
                                    color: ColorManager.kTitleTextColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                // CustomRoundButton(
                                //   fct: () => {_saveTemplates(showMessage: true)},
                                //   title: 'Manual Save',
                                //   height: 36,
                                //   width: 120,
                                //   fontSize: 12,
                                //   borderColor: ColorManager.kPrimaryColor,
                                //   boxColor: Colors.white,
                                //   textColor: ColorManager.kPrimaryColor,
                                // ),
                                // const SizedBox(width: 10),
                                CustomRoundButton(
                                  fct: () => {clearDefaultPrinter()},
                                  title: 'Clear Default Printer',
                                  height: 40,
                                  width: 200,
                                  fontSize: 14,
                                  borderColor: ColorManager.kButtonRed,
                                  boxColor: ColorManager.kButtonRed,
                                  textColor: Colors.white,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Current Default Printer Section
                        if (selectedPrinter != null)
                          BuildBoxShadowContainer(
                            circleRadius: 7,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            color: Colors.white,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: ColorManager.kPrimaryColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      child: const Icon(
                                        Icons.print,
                                        color: ColorManager.kPrimaryColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedPrinter!.deviceName ??
                                                'Unknown Printer',
                                            style: const TextStyle(
                                              color:
                                                  ColorManager.kTitleTextColor,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          // const SizedBox(height: 4),
                                          // Text(
                                          //   selectedPrinter!.address ??
                                          //       'No address',
                                          //   style: const TextStyle(
                                          //     color: ColorManager.kGreyColor,
                                          //     fontSize: 14,
                                          //   ),
                                          // ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Type: ${selectedPrinter!.typePrinter}',
                                            style: const TextStyle(
                                              color: ColorManager.kGreyColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                        // Template Selection Grid
                        BuildBoxShadowContainer(
                          circleRadius: 7,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          margin: const EdgeInsets.only(top: 10),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Select Template',
                                    style: TextStyle(
                                      color: ColorManager.kPrimaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  CustomRoundButton(
                                    fct: () => {_createNewTemplate()},
                                    title: '+ New Template',
                                    height: 36,
                                    width: 120,
                                    fontSize: 12,
                                    borderColor: ColorManager.kPrimaryColor,
                                    boxColor: ColorManager.kPrimaryColor,
                                    textColor: Colors.white,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 44,
                                child: Scrollbar(
                                  controller: _templatesScrollController,
                                  thumbVisibility: true,
                                  thickness: 4,
                                  radius: const Radius.circular(10),
                                  scrollbarOrientation:
                                      ScrollbarOrientation.bottom,
                                  child: SingleChildScrollView(
                                    controller: _templatesScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: List.generate(templates.length,
                                          (index) {
                                        final template = templates[index];
                                        final isSelected =
                                            selectedTemplate?.id == template.id;

                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              selectedTemplate = template;
                                              isEditing = false;
                                            });
                                          },
                                          child: Container(
                                            width: 150,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? ColorManager.kPrimaryColor
                                                      .withOpacity(0.1)
                                                  : Colors.grey
                                                      .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? ColorManager.kPrimaryColor
                                                    : Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    template.name,
                                                    style: TextStyle(
                                                      color: ColorManager
                                                          .kTitleTextColor,
                                                      fontSize: 12,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                                if (template.isDefault)
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 4),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 3,
                                                      vertical: 1,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: ColorManager
                                                          .kPrimaryColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              3),
                                                    ),
                                                    child: const Text(
                                                      'Default',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 7,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectedTemplate != null && isEditing)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Editing section header with rename button
                          BuildBoxShadowContainer(
                            circleRadius: 7,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            margin: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 5),
                            color: Colors.white,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.edit_document,
                                      color: ColorManager.kPrimaryColor,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Editing: ${selectedTemplate!.name}',
                                      style: const TextStyle(
                                        color: ColorManager.kTitleTextColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    CustomRoundButton(
                                      fct: () =>
                                          {_saveTemplates(showMessage: true)},
                                      title: 'Save',
                                      height: 40,
                                      width: 100,
                                      fontSize: 14,
                                      borderColor: ColorManager.kPrimaryColor,
                                      boxColor: Colors.white,
                                      textColor: ColorManager.kPrimaryColor,
                                    ),
                                    const SizedBox(width: 10),
                                    CustomRoundButton(
                                      fct: () {
                                        showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            final TextEditingController
                                                nameController =
                                                TextEditingController(
                                              text: selectedTemplate!.name,
                                            );
                                            return Dialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(24),
                                              ),
                                              elevation: 8,
                                              backgroundColor: Colors.white,
                                              child: Container(
                                                constraints:
                                                    const BoxConstraints(
                                                        maxWidth: 400),
                                                padding:
                                                    const EdgeInsets.all(24),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    // Header with close button
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        const Text(
                                                          "Rename Template",
                                                          style: TextStyle(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                        IconButton(
                                                          icon: const Icon(
                                                              Icons.close,
                                                              color:
                                                                  Colors.black),
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                      context)
                                                                  .pop(),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),

                                                    // Template name input
                                                    TextField(
                                                      controller:
                                                          nameController,
                                                      decoration:
                                                          InputDecoration(
                                                        labelText:
                                                            'Template Name',
                                                        border:
                                                            OutlineInputBorder(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                        ),
                                                        filled: true,
                                                        fillColor:
                                                            Colors.grey[100],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 24),

                                                    // Action buttons
                                                    Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment.end,
                                                      children: [
                                                        CustomRoundButton(
                                                          fct: () =>
                                                              Navigator.pop(
                                                                  context),
                                                          title: "Cancel",
                                                          height: 40,
                                                          width: 100,
                                                          fontSize: 14,
                                                          borderColor:
                                                              Colors.grey,
                                                          boxColor:
                                                              Colors.white,
                                                          textColor:
                                                              Colors.grey[700]!,
                                                        ),
                                                        const SizedBox(
                                                            width: 12),
                                                        CustomRoundButton(
                                                          fct: () {
                                                            _renameTemplate(
                                                                selectedTemplate!,
                                                                nameController
                                                                    .text);
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          title: "Save",
                                                          height: 40,
                                                          width: 100,
                                                          fontSize: 14,
                                                          borderColor:
                                                              ColorManager
                                                                  .kPrimaryColor,
                                                          boxColor: ColorManager
                                                              .kPrimaryColor,
                                                          textColor:
                                                              Colors.white,
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      title: 'Rename',
                                      height: 40,
                                      width: 100,
                                      fontSize: 14,
                                      borderColor: ColorManager.kPrimaryColor,
                                      boxColor: ColorManager.kPrimaryColor,
                                      textColor: Colors.white,
                                    ),
                                    if (templates.length > 1) ...[
                                      const SizedBox(width: 10),
                                      CustomRoundButton(
                                        fct: () {
                                          // Show delete confirmation dialog using reusable component
                                          DeleteConfirmationDialog.show(
                                            context: context,
                                            title: "Delete Template",
                                            itemName: selectedTemplate!.name,
                                            message: "This action cannot be undone.",
                                            onDelete: () {
                                              _deleteTemplate(selectedTemplate!);
                                            },
                                          );
                                        },
                                        title: 'Delete',
                                        height: 40,
                                        width: 100,
                                        fontSize: 14,
                                        borderColor: ColorManager.kButtonRed,
                                        boxColor: ColorManager.kButtonRed,
                                        textColor: Colors.white,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Side by side layout for settings and preview
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Side - Settings
                              Expanded(
                                flex: 1,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      _buildSettingsSection(
                                        'Store Header',
                                        [
                                          _buildSwitchTile(
                                            'Store Name',
                                            selectedTemplate!
                                                .settings.showStoreName,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showStoreName = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'Telephone',
                                            selectedTemplate!.settings.showTel,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showTel = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'Email',
                                            selectedTemplate!
                                                .settings.showEmail,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showEmail = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'Invoice Number',
                                            selectedTemplate!
                                                .settings.showInvoiceNumber,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showInvoiceNumber =
                                                  value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                        ],
                                      ),
                                      _buildSettingsSection(
                                        'Date Header',
                                        [
                                          _buildSwitchTile(
                                            'Show Date Header',
                                            selectedTemplate!
                                                .settings.showDateHeader,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showDateHeader =
                                                  value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                        ],
                                      ),
                                      _buildSettingsSection(
                                        'Cart Items',
                                        [
                                          _buildSwitchTile(
                                            'Particulars',
                                            selectedTemplate!
                                                .settings.showParticulars,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showParticulars =
                                                  value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'MRP',
                                            selectedTemplate!.settings.showMRP,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showMRP = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'Quantity',
                                            selectedTemplate!.settings.showQty,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showQty = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'Rate',
                                            selectedTemplate!.settings.showRate,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showRate = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'Total',
                                            selectedTemplate!
                                                .settings.showTotal,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showTotal = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                        ],
                                      ),
                                      _buildSettingsSection(
                                        'Amount Section',
                                        [
                                          _buildSwitchTile(
                                            'Discount',
                                            selectedTemplate!
                                                .settings.showDiscount,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showDiscount = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'Net Amount',
                                            selectedTemplate!
                                                .settings.showNetAmount,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showNetAmount = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'MRP Total',
                                            selectedTemplate!
                                                .settings.showMRPTotal,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showMRPTotal = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'You Save',
                                            selectedTemplate!
                                                .settings.showSaved,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showSaved = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                        ],
                                      ),
                                      _buildSettingsSection(
                                        'Additional Settings',
                                        [
                                          _buildSwitchTile(
                                            'Thank You Message',
                                            selectedTemplate!
                                                .settings.showThankYouMessage,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showThankYouMessage =
                                                  value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                          _buildSwitchTile(
                                            'QR Code',
                                            selectedTemplate!
                                                .settings.showQRCode,
                                            (value) {
                                              final newSettings =
                                                  selectedTemplate!.settings;
                                              newSettings.showQRCode = value;
                                              _updateSelectedTemplateSettings(
                                                  newSettings);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Divider
                              const SizedBox(width: 16),

                              // Right Side - Preview
                              Expanded(
                                flex: 1,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 10),
                                      Center(
                                        child: _buildReceiptPreview(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    if (selectedTemplate != null && !isEditing)
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                selectedTemplate!.name,
                                style: const TextStyle(
                                  color: ColorManager.kTitleTextColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (selectedTemplate!.isDefault)
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorManager.kPrimaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Default',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildActionButton(
                                  icon: Icons.edit,
                                  text: 'Edit',
                                  onTap: () {
                                    setState(() {
                                      isEditing = true;
                                    });
                                  },
                                  color: ColorManager.kPrimaryColor,
                                ),
                                if (!selectedTemplate!.isDefault) ...[
                                  const SizedBox(width: 12),
                                  _buildActionButton(
                                    icon: Icons.star,
                                    text: 'Set Default',
                                    onTap: () =>
                                        _setDefaultTemplate(selectedTemplate!),
                                    color: ColorManager.kPrimaryColor,
                                    isOutlined: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Center(
                            child: _buildReceiptPreview(),
                          ),
                        ],
                      ),
                    if (selectedTemplate == null)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 40),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No template selected",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: ColorManager.kTitleTextColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Select a template from above to view or edit",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: ColorManager.kGreyColor,
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
    );
  }
}
