import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/providers/grid_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';

class AddProductMobileScreen extends StatefulWidget {
  const AddProductMobileScreen({super.key});

  @override
  State<AddProductMobileScreen> createState() => _AddProductMobileScreenState();
}

class _AddProductMobileScreenState extends State<AddProductMobileScreen> {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep3 = GlobalKey<FormState>();

  int _currentStep = 1;
  bool _isLoading = false;
  bool _isGeneratingBarcode = false;

  // Step 1 Controllers & State
  final _productNameController = TextEditingController();
  final _barcodeController = TextEditingController();
  Category? _selectedCategory;

  // Step 2 Controllers & State (Localization)
  final Map<int, TextEditingController> _languageNameControllers = {};
  final Map<int, bool> _languageTranslating = {};

  // Step 3 Controllers & State (Pricing)
  String? _selectedUnit;
  final _purchasePriceController = TextEditingController(text: '0.00');
  final _mrpController = TextEditingController(text: '0.00');
  final _sellingPriceController = TextEditingController(text: '0.00');
  final _quantityController = TextEditingController(text: '0.00');
  final _itemCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialData();
    });
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _barcodeController.dispose();
    for (var controller in _languageNameControllers.values) {
      controller.dispose();
    }
    _purchasePriceController.dispose();
    _mrpController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _itemCodeController.dispose();
    super.dispose();
  }

  void _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final token = Provider.of<AuthModel>(context, listen: false).token ?? '';
      
      // Fetch languages
      await Provider.of<LanguageProvider>(context, listen: false)
          .fetchLanguages(accessToken: token);

      // Initialize default unit
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      final unitList = purchaseProvider.getUnitList ?? const <String, String>{};
      if (unitList.isNotEmpty && _selectedUnit == null) {
        setState(() {
          _selectedUnit = unitList.keys.first;
        });
      }
    } catch (e) {
      debugPrint('Error fetching initial product creation data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateBarcode() async {
    if (_isGeneratingBarcode) return;
    setState(() => _isGeneratingBarcode = true);

    try {
      final token = Provider.of<AuthModel>(context, listen: false).token ?? '';
      final gridProvider = Provider.of<GridSelectionProvider>(context, listen: false);
      final result = await gridProvider.generateBarcodeAPI(accessToken: token);

      if (result != null && result['status'] == 'success' && result['data'] != null) {
        final generatedBarcode = result['data']['barcode'];
        setState(() {
          _barcodeController.text = generatedBarcode;
        });
        showScaffold(
          context: context,
          message: 'Barcode generated successfully',
        );
      } else {
        showScaffoldError(
          context: context,
          message: result?['message'] ?? 'Failed to generate barcode',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Error generating barcode: $e',
      );
    } finally {
      setState(() => _isGeneratingBarcode = false);
    }
  }

  Future<void> _translateLanguage(Language language) async {
    final baseText = _productNameController.text.trim();
    if (baseText.isEmpty) {
      showScaffoldError(
        context: context,
        message: 'Please enter Product Name before translating.',
      );
      return;
    }

    if (_languageTranslating[language.id] == true) return;

    setState(() {
      _languageTranslating[language.id] = true;
    });

    try {
      final token = Provider.of<AuthModel>(context, listen: false).token ?? '';
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

      final translated = await languageProvider.translateText(
        accessToken: token,
        targetLang: language.code,
        text: baseText,
      );

      if (!mounted) return;

      if (translated != null && translated.isNotEmpty) {
        setState(() {
          _languageNameControllers[language.id]?.text = translated;
        });
        showScaffold(
          context: context,
          message: 'Translated to ${language.name}',
        );
      } else {
        showScaffoldError(
          context: context,
          message: 'Translation failed. Please try again.',
        );
      }
    } catch (e) {
      showScaffoldError(
        context: context,
        message: 'Translation failed: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _languageTranslating[language.id] = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _buildProductNamesPayload() {
    final payload = <Map<String, dynamic>>[];
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    for (final language in languageProvider.languages) {
      if (language.code.toLowerCase() == 'en') continue;
      final controller = _languageNameControllers[language.id];
      final text = controller?.text.trim() ?? '';
      if (text.isNotEmpty) {
        payload.add({
          'language_id': language.id,
          'name': text,
        });
      }
    }
    return payload;
  }

  void _submitForm() async {
    if (!_formKeyStep3.currentState!.validate() || _selectedUnit == null) {
      showScaffoldError(context: context, message: 'Please fix validation errors.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = Provider.of<AuthModel>(context, listen: false).token ?? '';
      final gridProvider = Provider.of<GridSelectionProvider>(context, listen: false);
      final productNames = _buildProductNamesPayload();

      final result = await gridProvider.createProductAPI(
        categoryId: _selectedCategory!.categoryId.toString(),
        productName: _productNameController.text.trim(),
        sellingPrice: _sellingPriceController.text.trim(),
        mrp: _mrpController.text.trim(),
        unit: _selectedUnit!,
        quantity: _quantityController.text.trim(),
        barcode: _barcodeController.text.trim(),
        accessToken: token,
        purchasePrice: _purchasePriceController.text.trim(),
        productNames: productNames.isNotEmpty ? productNames : null,
        conversionRateBase: '1',
        itemCode: _itemCodeController.text.trim().isNotEmpty 
            ? _itemCodeController.text.trim() 
            : null,
      );

      if (!mounted) return;

      if (result is Map<String, dynamic> && result.containsKey('data')) {
        try {
          GetProduct product = GetProduct.fromJson(result['data']);
          Provider.of<LocalProductProvider>(context, listen: false).addProduct(product);
        } catch (e) {
          debugPrint('Error parsing added product: $e');
        }

        Provider.of<LocalProductProvider>(context, listen: false).refreshProducts();
        showScaffold(context: context, message: 'Product added successfully');
        Navigator.pop(context);
      } else {
        String errMsg = 'Failed to add product';
        if (result is Map<String, dynamic> && result.containsKey('message')) {
          errMsg = result['message'].toString();
        }
        showScaffoldError(context: context, message: errMsg);
      }
    } catch (e) {
      showScaffoldError(context: context, message: 'Error creating product: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _resetFields() {
    setState(() {
      _purchasePriceController.text = '0.00';
      _mrpController.text = '0.00';
      _sellingPriceController.text = '0.00';
      _quantityController.text = '0.00';
      _itemCodeController.clear();
      _productNameController.clear();
      _barcodeController.clear();
      _selectedCategory = null;
      for (var controller in _languageNameControllers.values) {
        controller.clear();
      }
      _currentStep = 1;
    });
  }

  Widget _buildStepIndicator(int stepNumber, String title) {
    final isActive = _currentStep == stepNumber;
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? ColorManager.kPrimaryColor : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$stepNumber',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isActive ? ColorManager.kPrimaryColor : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Expanded(
      child: Container(
        height: 1.5,
        color: Colors.grey.shade300,
        margin: const EdgeInsets.only(bottom: 22),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add New Product',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey.shade100,
            height: 1,
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stepper Progress Row
                  Row(
                    children: [
                      _buildStepIndicator(1, 'Basic Info'),
                      _buildStepDivider(),
                      _buildStepIndicator(2, 'Localization'),
                      _buildStepDivider(),
                      _buildStepIndicator(3, 'Pricing'),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Content Wizard Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.shade50,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade50,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildStepContent(),
                  ),
                  const SizedBox(height: 28),

                  // Bottom Action Buttons
                  _buildBottomActions(),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(ColorManager.kPrimaryColor),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return Form(
          key: _formKeyStep1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card Label
              Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Basic Information',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Product Name
              _buildInputField(
                label: 'Product Name',
                hintText: 'e.g. Premium Coffee Beans',
                controller: _productNameController,
                isRequired: true,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Product Name is required'
                    : null,
              ),
              const SizedBox(height: 18),

              // Barcode Input
              _buildInputField(
                label: 'Barcode',
                hintText: 'Scanning code...',
                controller: _barcodeController,
                isRequired: true,
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Barcode is required'
                    : null,
                suffixIcon: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ColorManager.kPrimaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: _isGeneratingBarcode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                    onPressed: _generateBarcode,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Category dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Product Category',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<CategoryProvider>(
                    builder: (context, categoryProvider, child) {
                      final allCats = categoryProvider.categoryList ?? [];
                      final categories = allCats
                          .where((c) =>
                              c.categoryId != 0 &&
                              c.categoryName != 'ALL' &&
                              c.categoryName != 'All products')
                          .toList();

                      return CustomDropDownWithSearch<Category>(
                        hintText: 'Select Category...',
                        value: _selectedCategory,
                        items: categories,
                        autofocus: false,
                        isRequired: true,
                        onChanged: (cat) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                        displayText: (cat) => cat.categoryName ?? '',
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );

      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.translate, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Other Language Names',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Consumer<LanguageProvider>(
              builder: (context, langProvider, child) {
                final activeLangs = langProvider.languages
                    .where((l) => l.code.toLowerCase() != 'en')
                    .toList();

                if (activeLangs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No other languages available.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeLangs.length,
                  separatorBuilder: (c, idx) => const SizedBox(height: 18),
                  itemBuilder: (context, index) {
                    final language = activeLangs[index];
                    _languageNameControllers.putIfAbsent(
                        language.id, () => TextEditingController());
                    _languageTranslating.putIfAbsent(
                        language.id, () => false);

                    final isTranslating = _languageTranslating[language.id] == true;

                    return _buildInputField(
                      label: 'Product Name (${language.name})',
                      hintText: 'Enter name in ${language.name}',
                      controller: _languageNameControllers[language.id]!,
                      suffixIcon: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: ColorManager.kPrimaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: isTranslating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  '文A',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          onPressed: () => _translateLanguage(language),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );

      case 3:
        return Form(
          key: _formKeyStep3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: Colors.blue.shade700, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Pricing & Stock',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Product Unit
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Product Unit',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<PurchaseProvider>(
                    builder: (context, purchaseProvider, child) {
                      final unitList = purchaseProvider.getUnitList ?? const <String, String>{};
                      
                      return CustomDropDownWithSearch<String>(
                        hintText: 'Select Unit...',
                        value: _selectedUnit,
                        items: unitList.keys.toList(),
                        autofocus: false,
                        isRequired: true,
                        onChanged: (unitKey) {
                          setState(() {
                            _selectedUnit = unitKey;
                          });
                        },
                        displayText: (unitKey) => unitList[unitKey] ?? unitKey,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Purchase Price & Max Sale Price Row
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'Purchase Price',
                      hintText: '0.00',
                      controller: _purchasePriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInputField(
                      label: 'Max Sale Price / Mrp',
                      hintText: '0.00',
                      controller: _mrpController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Selling Price & Initial Quantity Row
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'Selling Price',
                      hintText: '0.00',
                      controller: _sellingPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInputField(
                      label: 'Initial Quantity',
                      hintText: '0.00',
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Item Code (Sku)
              _buildInputField(
                label: 'Item Code (Sku)',
                hintText: 'PROD-12345',
                controller: _itemCodeController,
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomActions() {
    if (_currentStep == 1) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.kPrimaryColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        onPressed: () {
          if (_formKeyStep1.currentState!.validate() && _selectedCategory != null) {
            setState(() {
              _currentStep = 2;
            });
          } else if (_selectedCategory == null) {
            showScaffoldError(context: context, message: 'Please select a Category.');
          }
        },
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Next',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      );
    } else if (_currentStep == 2) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              child: Text(
                'Back',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _currentStep = 3;
                });
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Next',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _resetFields,
              child: Text(
                'Clear',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _submitForm,
              child: const Text(
                'Save Product',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }
}
