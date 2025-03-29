import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_delete_confirmation_dialog.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/screens/login/login.dart';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/local_models.dart';

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
  bool showDescription;
  bool showTel;
  bool showEmail;
  bool showInvoiceNumber;
  bool showStoreAddress;
  bool showFssaiInfo;

  // Store Header content
  String storeName;
  String description;
  String storeAddress;
  String fssaiInfo;
  String telephone;
  String email;

  // Date Header settings
  bool showDateHeader;

  // Cart Items settings
  // These will be removed from toggles but kept in the model for backwards compatibility
  bool showSLNumber;
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
  bool showAmountInWords;

  // Additional settings
  bool showThankYouMessage;
  bool showQRCode;
  bool showTermsConditions;

  // Additional content
  String thankYouMessage;
  String termsConditions;
  String qrCodeMessage;

  ReceiptSettings({
    this.showStoreName = true,
    this.showDescription = true,
    this.showTel = true,
    this.showEmail = true,
    this.showInvoiceNumber = true,
    this.showStoreAddress = true,
    this.showFssaiInfo = true,
    this.showDateHeader = true,
    this.showSLNumber = true,
    this.showParticulars = true,
    this.showMRP = true,
    this.showQty = true,
    this.showRate = true,
    this.showTotal = true,
    this.showDiscount = true,
    this.showNetAmount = true,
    this.showMRPTotal = true,
    this.showSaved = true,
    this.showAmountInWords = true,
    this.showThankYouMessage = true,
    this.showQRCode = true,
    this.showTermsConditions = true,
    this.storeName = 'STORE NAME',
    this.description = 'Mini Supermarket',
    this.storeAddress = 'Manjeri, Malappuram',
    this.fssaiInfo = 'Fssai: xxxx',
    this.telephone = 'TEL: 123-456-7890',
    this.email = 'Email: example@store.com',
    this.thankYouMessage = 'Thank You... Visit Again',
    this.termsConditions =
        '1. Replace within 7 Days of Purchase\n2. Replace only with Bill',
    this.qrCodeMessage = 'Scan this QR code to Pay',
  });

  Map<String, dynamic> toJson() {
    return {
      'showStoreName': showStoreName,
      'showDescription': showDescription,
      'showTel': showTel,
      'showEmail': showEmail,
      'showInvoiceNumber': showInvoiceNumber,
      'showStoreAddress': showStoreAddress,
      'showFssaiInfo': showFssaiInfo,
      'showDateHeader': showDateHeader,
      'showSLNumber': showSLNumber,
      'showParticulars': showParticulars,
      'showMRP': showMRP,
      'showQty': showQty,
      'showRate': showRate,
      'showTotal': showTotal,
      'showDiscount': showDiscount,
      'showNetAmount': showNetAmount,
      'showMRPTotal': showMRPTotal,
      'showSaved': showSaved,
      'showAmountInWords': showAmountInWords,
      'showThankYouMessage': showThankYouMessage,
      'showQRCode': showQRCode,
      'showTermsConditions': showTermsConditions,
      'storeName': storeName,
      'description': description,
      'storeAddress': storeAddress,
      'fssaiInfo': fssaiInfo,
      'telephone': telephone,
      'email': email,
      'thankYouMessage': thankYouMessage,
      'termsConditions': termsConditions,
      'qrCodeMessage': qrCodeMessage,
    };
  }

  factory ReceiptSettings.fromJson(Map<String, dynamic> json) {
    return ReceiptSettings(
      showStoreName: json['showStoreName'] ?? true,
      showDescription: json['showDescription'] ?? true,
      showTel: json['showTel'] ?? true,
      showEmail: json['showEmail'] ?? true,
      showInvoiceNumber: json['showInvoiceNumber'] ?? true,
      showStoreAddress: json['showStoreAddress'] ?? true,
      showFssaiInfo: json['showFssaiInfo'] ?? true,
      showDateHeader: json['showDateHeader'] ?? true,
      showSLNumber: json['showSLNumber'] ?? true,
      showParticulars: json['showParticulars'] ?? true,
      showMRP: json['showMRP'] ?? true,
      showQty: json['showQty'] ?? true,
      showRate: json['showRate'] ?? true,
      showTotal: json['showTotal'] ?? true,
      showDiscount: json['showDiscount'] ?? true,
      showNetAmount: json['showNetAmount'] ?? true,
      showMRPTotal: json['showMRPTotal'] ?? true,
      showSaved: json['showSaved'] ?? true,
      showAmountInWords: json['showAmountInWords'] ?? true,
      showThankYouMessage: json['showThankYouMessage'] ?? true,
      showQRCode: json['showQRCode'] ?? true,
      showTermsConditions: json['showTermsConditions'] ?? true,
      storeName: json['storeName'] ?? 'STORE NAME',
      description: json['description'] ?? 'Your one-stop shop for all needs',
      storeAddress: json['storeAddress'] ?? 'Manjeri, Malappuram',
      fssaiInfo: json['fssaiInfo'] ?? 'Fssai: xxxx',
      telephone: json['telephone'] ?? 'TEL: 123-456-7890',
      email: json['email'] ?? 'Email: example@store.com',
      thankYouMessage: json['thankYouMessage'] ?? 'Thank You... Visit Again',
      termsConditions: json['termsConditions'] ??
          '1. Replace within 7 Days of Purchase\n2. Replace only with Bill',
      qrCodeMessage: json['qrCodeMessage'] ?? 'Scan this QR code to Pay',
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
  List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _templatesScrollController.dispose();
    // Make sure to clean up all focus nodes
    for (var element in _focusNodes) {
      element.dispose();
    }
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

  Future<void> clearLocalStorageAndLogout() async {
    try {
      // Show confirmation dialog
      final shouldClear = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Local Storage'),
          content: const Text(
            'This will clear all local data except login credentials and log you out. Are you sure?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Clear & Logout',
                style: TextStyle(color: ColorManager.kButtonRed),
              ),
            ),
          ],
        ),
      );

      if (shouldClear != true) return;

      final prefs = await SharedPreferences.getInstance();

      // Save login credentials before clearing
      final String? emailRemember = prefs.getString('emailRemember');
      final String? passwordRemember = prefs.getString('passwordRemember');
      final bool? rememberMe = prefs.getBool('remember_me');

      // Clear all SharedPreferences except login credentials
      await prefs.clear();

      // Restore login credentials if needed
      if (rememberMe == true) {
        await prefs.setBool('remember_me', true);
        if (emailRemember != null)
          await prefs.setString('emailRemember', emailRemember);
        if (passwordRemember != null)
          await prefs.setString('passwordRemember', passwordRemember);
      }

      // Clear Hive data
      if (Hive.isBoxOpen('products')) {
        await Hive.box<HiveProduct>('products').clear();
      }

      if (Hive.isBoxOpen('cart_items')) {
        await Hive.box<HiveLocalCartItem>('cart_items').clear();
      }

      if (Hive.isBoxOpen('saved_orders')) {
        await Hive.box<HiveSavedOrder>('saved_orders').clear();
      }

      if (Hive.isBoxOpen('confirmed_orders')) {
        await Hive.box<HiveSavedOrder>('confirmed_orders').clear();
      }

      // Log out - clear auth data from provider
      final authModel = Provider.of<AuthModel>(context, listen: false);
      authModel.logout();

      if (mounted) {
        showScaffold(
          context: context,
          message: "Local storage cleared successfully",
        );

        // Navigate to login screen after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const SignInScreen()),
            (route) => false,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: "Error clearing local storage: ${e.toString()}",
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
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final appSettings = appSettingsProvider.appSettings;

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
              Text(
                settings.storeName.isNotEmpty
                    ? settings.storeName
                    : 'STORE NAME',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            if (settings.showDescription)
              Text(
                settings.description.isNotEmpty
                    ? settings.description
                    : 'Your one-stop shop for all needs',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            if (settings.showStoreAddress)
              Text(
                settings.storeAddress.isNotEmpty
                    ? settings.storeAddress
                    : 'Shop Address',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showFssaiInfo)
              Text(
                settings.fssaiInfo.isNotEmpty
                    ? settings.fssaiInfo
                    : 'Fssai: xxxx',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showTel)
              Text(
                settings.telephone.isNotEmpty
                    ? settings.telephone
                    : 'TEL: ${appSettings?.customerCarePhone ?? ""}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showEmail)
              Text(
                settings.email.isNotEmpty
                    ? settings.email
                    : 'Email: ${appSettings?.customerCareEmail ?? ""}',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            if (settings.showInvoiceNumber)
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'INVOICE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'INV No: 12345',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            const Divider(),

            // Date Header
            if (settings.showDateHeader)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                    if (settings.showSLNumber)
                      const Expanded(
                        flex: 1,
                        child: Text(
                          'SL#',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
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
                        if (settings.showSLNumber)
                          Expanded(
                            flex: 1,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
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
            if (settings.showMRPTotal)
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Items',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '2',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

            if (settings.showNetAmount)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Net Total',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '300.00',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            if (settings.showMRPTotal)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total MRP',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '315.00',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            if (settings.showSaved)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'You Saved',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '15.00',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

            if (settings.showMRPTotal || settings.showSaved) const Divider(),

            if (settings.showAmountInWords) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  'Three Hundred Rupees Only.',
                  style: TextStyle(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(),
            ],

            // Thank You Message
            if (settings.showThankYouMessage)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  settings.thankYouMessage,
                  style: const TextStyle(
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
              Text(
                settings.qrCodeMessage,
                style: const TextStyle(fontSize: 10),
              ),
            ],

            // Terms & Conditions
            if (settings.showTermsConditions) ...[
              const SizedBox(height: 8),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.left,
                      ),
                      Text(
                        settings.termsConditions,
                        style: const TextStyle(fontSize: 9),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ],
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

    return settings.showSLNumber ||
        settings.showParticulars ||
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

  Column _buildSettingsForm() {
    if (selectedTemplate == null) return const Column();

    return Column(
      children: [
        _buildSettingsSection(
          'Store Header',
          [
            _buildSwitchTile(
              'Store Name',
              selectedTemplate!.settings.showStoreName,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showStoreName = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showStoreName)
              _buildTextEditField(
                label: 'Store Name Content',
                value: selectedTemplate!.settings.storeName,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.storeName = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
              ),
            _buildSwitchTile(
              'Store Description',
              selectedTemplate!.settings.showDescription,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showDescription = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showDescription)
              _buildTextEditField(
                label: 'Store Description Content',
                value: selectedTemplate!.settings.description,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.description = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
              ),
            _buildSwitchTile(
              'Store Address',
              selectedTemplate!.settings.showStoreAddress,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showStoreAddress = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showStoreAddress)
              _buildTextEditField(
                label: 'Store Address Content',
                value: selectedTemplate!.settings.storeAddress,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.storeAddress = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
              ),
            _buildSwitchTile(
              'FSSAI Info',
              selectedTemplate!.settings.showFssaiInfo,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showFssaiInfo = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showFssaiInfo)
              _buildTextEditField(
                label: 'FSSAI Info Content',
                value: selectedTemplate!.settings.fssaiInfo,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.fssaiInfo = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
              ),
            _buildSwitchTile(
              'Telephone',
              selectedTemplate!.settings.showTel,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showTel = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showTel)
              _buildTextEditField(
                label: 'Telephone Content',
                value: selectedTemplate!.settings.telephone,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.telephone = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
              ),
            _buildSwitchTile(
              'Email',
              selectedTemplate!.settings.showEmail,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showEmail = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showEmail)
              _buildTextEditField(
                label: 'Email Content',
                value: selectedTemplate!.settings.email,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.email = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
              ),
            _buildSwitchTile(
              'Invoice Number',
              selectedTemplate!.settings.showInvoiceNumber,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showInvoiceNumber = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
          ],
        ),
        _buildSettingsSection(
          'Date Header',
          [
            _buildSwitchTile(
              'Show Date Header',
              selectedTemplate!.settings.showDateHeader,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showDateHeader = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
          ],
        ),
        _buildSettingsSection(
          'Amount Section',
          [
            _buildSwitchTile(
              'Discount',
              selectedTemplate!.settings.showDiscount,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showDiscount = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            _buildSwitchTile(
              'Net Total',
              selectedTemplate!.settings.showNetAmount,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showNetAmount = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            _buildSwitchTile(
              'MRP Total',
              selectedTemplate!.settings.showMRPTotal,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showMRPTotal = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            _buildSwitchTile(
              'You Save',
              selectedTemplate!.settings.showSaved,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showSaved = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            _buildSwitchTile(
              'Amount in Words',
              selectedTemplate!.settings.showAmountInWords,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showAmountInWords = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
          ],
        ),
        _buildSettingsSection(
          'Additional Settings',
          [
            _buildSwitchTile(
              'Thank You Message',
              selectedTemplate!.settings.showThankYouMessage,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showThankYouMessage = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showThankYouMessage)
              _buildTextEditField(
                label: 'Thank You Message Content',
                value: selectedTemplate!.settings.thankYouMessage,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.thankYouMessage = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
              ),
            _buildSwitchTile(
              'QR Code',
              selectedTemplate!.settings.showQRCode,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showQRCode = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showQRCode)
              _buildTextEditField(
                label: 'QR Code Message',
                value: selectedTemplate!.settings.qrCodeMessage,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.qrCodeMessage = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
              ),
            _buildSwitchTile(
              'Terms & Conditions',
              selectedTemplate!.settings.showTermsConditions,
              (value) {
                final newSettings = selectedTemplate!.settings;
                newSettings.showTermsConditions = value;
                _updateSelectedTemplateSettings(newSettings);
              },
            ),
            if (selectedTemplate!.settings.showTermsConditions)
              _buildTextEditField(
                label: 'Terms & Conditions Content',
                value: selectedTemplate!.settings.termsConditions,
                onChanged: (value) {
                  final newSettings = selectedTemplate!.settings;
                  newSettings.termsConditions = value;
                  _updateSelectedTemplateSettings(newSettings);
                },
                maxLines: 4,
              ),
          ],
        ),
      ],
    );
  }

  // Show receipt template modal
  void _showReceiptTemplateModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: ContentBox(context),
        );
      },
    );
  }

  // Content box for receipt template modal
  Widget ContentBox(BuildContext context) {
    final TextEditingController nameController = TextEditingController(
      text: selectedTemplate?.name ?? "",
    );

    return Container(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10.0,
            offset: Offset(0.0, 10.0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: ColorManager.kPrimaryColor,
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Receipt Template Settings",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: ColorManager.kTitleTextColor,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),

          // Template name input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                const Text(
                  "Template Name:",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: ColorManager.kTitleTextColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Enter template name",
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tabs for Content vs Visibility
          DefaultTabController(
            length: 2,
            child: Expanded(
              child: Column(
                children: [
                  const TabBar(
                    labelColor: ColorManager.kPrimaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: ColorManager.kPrimaryColor,
                    tabs: [
                      Tab(text: "Visibility Settings"),
                      Tab(text: "Content Settings"),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Visibility Settings Tab
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildSettingsSection(
                                'Store Header',
                                [
                                  _buildSwitchTile(
                                    'Store Name',
                                    selectedTemplate!.settings.showStoreName,
                                    (value) {
                                      final newSettings =
                                          selectedTemplate!.settings;
                                      newSettings.showStoreName = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                  _buildSwitchTile(
                                    'Store Description',
                                    selectedTemplate!.settings.showDescription,
                                    (value) {
                                      final newSettings =
                                          selectedTemplate!.settings;
                                      newSettings.showDescription = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                  if (selectedTemplate!.settings.showStoreName)
                                    _buildTextEditField(
                                      label: 'Store Name Content',
                                      value:
                                          selectedTemplate!.settings.storeName,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.storeName = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  if (selectedTemplate!
                                      .settings.showDescription)
                                    _buildTextEditField(
                                      label: 'Store Description Content',
                                      value: selectedTemplate!
                                          .settings.description,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.description = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  _buildSwitchTile(
                                    'Store Address',
                                    selectedTemplate!.settings.showStoreAddress,
                                    (value) {
                                      final newSettings =
                                          selectedTemplate!.settings;
                                      newSettings.showStoreAddress = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                  if (selectedTemplate!
                                      .settings.showStoreAddress)
                                    _buildTextEditField(
                                      label: 'Store Address Content',
                                      value: selectedTemplate!
                                          .settings.storeAddress,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.storeAddress = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  _buildSwitchTile(
                                    'FSSAI Info',
                                    selectedTemplate!.settings.showFssaiInfo,
                                    (value) {
                                      final newSettings =
                                          selectedTemplate!.settings;
                                      newSettings.showFssaiInfo = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                  if (selectedTemplate!.settings.showFssaiInfo)
                                    _buildTextEditField(
                                      label: 'FSSAI Info Content',
                                      value:
                                          selectedTemplate!.settings.fssaiInfo,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.fssaiInfo = value;
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
                                  if (selectedTemplate!.settings.showTel)
                                    _buildTextEditField(
                                      label: 'Telephone Content',
                                      value:
                                          selectedTemplate!.settings.telephone,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.telephone = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  _buildSwitchTile(
                                    'Email',
                                    selectedTemplate!.settings.showEmail,
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
                                      newSettings.showInvoiceNumber = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                ],
                              ),
                              // Other visibility settings...
                              _buildSettingsSection(
                                'Date Header',
                                [
                                  _buildSwitchTile(
                                    'Show Date Header',
                                    selectedTemplate!.settings.showDateHeader,
                                    (value) {
                                      final newSettings =
                                          selectedTemplate!.settings;
                                      newSettings.showDateHeader = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                ],
                              ),
                              // Cart Items section removed
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
                                      newSettings.showThankYouMessage = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                  _buildSwitchTile(
                                    'QR Code',
                                    selectedTemplate!.settings.showQRCode,
                                    (value) {
                                      final newSettings =
                                          selectedTemplate!.settings;
                                      newSettings.showQRCode = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                  _buildSwitchTile(
                                    'Terms & Conditions',
                                    selectedTemplate!
                                        .settings.showTermsConditions,
                                    (value) {
                                      final newSettings =
                                          selectedTemplate!.settings;
                                      newSettings.showTermsConditions = value;
                                      _updateSelectedTemplateSettings(
                                          newSettings);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Content Settings Tab
                        SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildSettingsSection(
                                'Store Information',
                                [
                                  if (selectedTemplate!.settings.showStoreName)
                                    _buildTextEditField(
                                      label: 'Store Name',
                                      value:
                                          selectedTemplate!.settings.storeName,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.storeName = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  if (selectedTemplate!
                                      .settings.showDescription)
                                    _buildTextEditField(
                                      label: 'Store Description',
                                      value: selectedTemplate!
                                          .settings.description,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.description = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  if (selectedTemplate!
                                      .settings.showStoreAddress)
                                    _buildTextEditField(
                                      label: 'Store Address',
                                      value: selectedTemplate!
                                          .settings.storeAddress,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.storeAddress = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  if (selectedTemplate!.settings.showFssaiInfo)
                                    _buildTextEditField(
                                      label: 'FSSAI Info',
                                      value:
                                          selectedTemplate!.settings.fssaiInfo,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.fssaiInfo = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  if (selectedTemplate!.settings.showTel)
                                    _buildTextEditField(
                                      label: 'Telephone',
                                      value:
                                          selectedTemplate!.settings.telephone,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.telephone = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  if (selectedTemplate!.settings.showEmail)
                                    _buildTextEditField(
                                      label: 'Email',
                                      value: selectedTemplate!.settings.email,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.email = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                ],
                              ),
                              _buildSettingsSection(
                                'Additional Content',
                                [
                                  if (selectedTemplate!
                                      .settings.showThankYouMessage)
                                    _buildTextEditField(
                                      label: 'Thank You Message',
                                      value: selectedTemplate!
                                          .settings.thankYouMessage,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.thankYouMessage = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  if (selectedTemplate!.settings.showQRCode)
                                    _buildTextEditField(
                                      label: 'QR Code Message',
                                      value: selectedTemplate!
                                          .settings.qrCodeMessage,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.qrCodeMessage = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                    ),
                                  if (selectedTemplate!
                                      .settings.showTermsConditions)
                                    _buildTextEditField(
                                      label: 'Terms & Conditions',
                                      value: selectedTemplate!
                                          .settings.termsConditions,
                                      onChanged: (value) {
                                        final newSettings =
                                            selectedTemplate!.settings;
                                        newSettings.termsConditions = value;
                                        _updateSelectedTemplateSettings(
                                            newSettings);
                                      },
                                      maxLines: 4,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CustomRoundButton(
                fct: () => Navigator.of(context).pop(),
                title: "Cancel",
                height: 40,
                width: 100,
                fontSize: 14,
                borderColor: ColorManager.kGreyColor,
                boxColor: Colors.white,
                textColor: ColorManager.kGreyColor,
              ),
              const SizedBox(width: 10),
              CustomRoundButton(
                fct: () {
                  if (selectedTemplate != null &&
                      nameController.text.isNotEmpty) {
                    _renameTemplate(selectedTemplate!, nameController.text);
                  }
                  _saveTemplates(showMessage: true);
                  Navigator.of(context).pop();
                },
                title: "Save",
                height: 40,
                width: 100,
                fontSize: 14,
                borderColor: ColorManager.kPrimaryColor,
                boxColor: ColorManager.kPrimaryColor,
                textColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextEditField({
    required String label,
    required String value,
    required Function(String) onChanged,
    int maxLines = 1,
  }) {
    final FocusNode focusNode = FocusNode();
    final TextEditingController controller = TextEditingController(text: value);

    // Add focus node to the list for later disposal
    _focusNodes.add(focusNode);

    // Add listener to handle focus changes
    focusNode.addListener(() {
      if (!focusNode.hasFocus) {
        // When focus is lost, trigger onChanged with current value
        onChanged(controller.text);
      }
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (text) {
                // We won't immediately save on every change
              },
              onSubmitted: onChanged, // Keep this for when Enter is pressed
            ),
          ),
        ],
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
                                CustomRoundButton(
                                  fct: () => {clearLocalStorageAndLogout()},
                                  title: 'Clear Local Storage',
                                  height: 40,
                                  width: 220,
                                  fontSize: 14,
                                  borderColor: Colors.orange,
                                  boxColor: Colors.orange,
                                  textColor: Colors.white,
                                ),
                                SizedBox(width: 10),
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
                                        _showReceiptTemplateModal(context);
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
                                            message:
                                                "This action cannot be undone.",
                                            onDelete: () {
                                              _deleteTemplate(
                                                  selectedTemplate!);
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
                                  child: _buildSettingsForm(),
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
