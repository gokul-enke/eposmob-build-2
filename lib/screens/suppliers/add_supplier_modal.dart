import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_multiselect_dropdown.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';

Future<dynamic> showAddSupplierModal(BuildContext context, Size size, {bool showCreateAnother = true}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: size.width / 2,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(24),
          child: AddSupplierModal(showCreateAnother: showCreateAnother),
        ),
      );
    },
  );
}

class AddSupplierModal extends StatefulWidget {
  final bool showCreateAnother;
  
  const AddSupplierModal({Key? key, this.showCreateAnother = true}) : super(key: key);

  @override
  State<AddSupplierModal> createState() => _AddSupplierModalState();
}

enum PaymentType { none, toPay, toReceive }

class _AddSupplierModalState extends State<AddSupplierModal> {
  final _formKey = GlobalKey<FormState>();
  final nameTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final altPhoneNumberController = TextEditingController();
  final addressTextController = TextEditingController();
  final categorySearchController = TextEditingController();
  final balanceTextController = TextEditingController();

  PaymentType selectedPaymentType = PaymentType.none;
  List<Category> selectedCategories = [];

  bool isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    // balanceTextController.text = '0.00';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
    });
  }

  Future<void> _loadCategories() async {
    setState(() {
      isLoadingCategories = true;
    });

    try {
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      await categoryProvider.listAllCategory();
    } catch (error) {
      debugPrint("Error loading categories: $error");
    } finally {
      setState(() {
        isLoadingCategories = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    Get.put(SideBarController());

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Add New Supplier",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Text(
            "Enter supplier details to add them to your system",
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          // Row 1: Name, Email
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Name TextField
              buildColumnWidgetForTextFields(
                autofocus: true,
                isStarRed: true,
                controller: nameTextController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'This field is required';
                  }
                  return null;
                },
                onchanged: (value) {
                  // Remove validation loop - only validate on submit
                },
                hintText: 'Supplier Name',
                size: size,
                width: size.width / 4.5,
              ),
              // Email TextField
              buildColumnWidgetForTextFields(
                autofocus: true,
                controller: emailTextController,
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
                onchanged: (value) {
                  // Remove validation loop - only validate on submit
                },
                hintText: 'Email Address',
                size: size,
                width: size.width / 4.5,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: Phone, Alt Phone
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Phone Number TextField
              buildColumnWidgetForTextFields(
                autofocus: true,
                isStarRed: true,
                controller: phoneNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [PhoneNumberFormatter()],
                validator: validatePhoneNumber,
                onchanged: (value) {
                  // Remove validation loop - only validate on submit
                },
                hintText: 'Phone Number',
                size: size,
                width: size.width / 4.5,
              ),
              // Alternative Phone TextField
              buildColumnWidgetForTextFields(
                autofocus: true,
                controller: altPhoneNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [PhoneNumberFormatter()],
                onchanged: (value) {
                  // Remove validation loop - only validate on submit
                },
                hintText: 'Alternative Phone',
                size: size,
                width: size.width / 4.5,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 3: Address, Balance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Address TextField
              buildColumnWidgetForTextFields(
                autofocus: true,
                controller: addressTextController,
                onchanged: (value) {
                  // Remove validation loop - only validate on submit
                },
                hintText: 'Address',
                size: size,
                width: size.width / 4.5,
              ),
              // Balance TextField
              buildColumnWidgetForTextFields(
                autofocus: true,
                controller: balanceTextController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
                onchanged: (value) {
                  // Remove validation loop - only validate on submit
                },
                hintText: 'Balance',
                size: size,
                width: size.width / 4.5,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Product Categories Section
          _buildCategoryMultiSelect(context, size),
          const SizedBox(height: 16),

          // Payment Section
          _buildPaymentSection(size),
          const SizedBox(height: 16),

          // Action Buttons
          _buildActionButtons(size, accessToken),
        ],
      ),
    );
  }

Widget _buildCategoryMultiSelect(BuildContext context, Size size) {
  final categoryProvider = Provider.of<CategoryProvider>(context);
  final categories = categoryProvider.category ?? [];

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      SizedBox(
        width: size.width / 2.2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BuildMultiSelectDropDownWithSearch<Category>(
              hintText: 'Select Categories',
              items: categories,
              selectedItems: selectedCategories,
              displayText: (cat) => cat.categoryName ?? "Unknown",
              onChanged: (selected) {
                setState(() {
                  selectedCategories = selected;
                });
              },
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildPaymentSection(Size size) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      SizedBox(
        width: size.width / 2.2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Payment Type *",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildRadioOption(
                  "To Pay",
                  PaymentType.toPay,
                ),
                const SizedBox(width: 24),
                _buildRadioOption(
                  "To Receive",
                  PaymentType.toReceive,
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}



  Widget _buildRadioOption(String title, PaymentType value) {
    return Row(
      children: [
        Radio<PaymentType>(
          value: value,
          groupValue: selectedPaymentType,
          activeColor: ColorManager.kPrimaryColor,
          onChanged: (PaymentType? newValue) {
            setState(() {
              selectedPaymentType = newValue!;
            });
          },
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.black.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Size size, String? accessToken) {
    List<Widget> buttons = [
      // Close Button
      CustomRoundButton(
        title: "Close",
        fontSize: FontSize.s12,
        height: MediaQuery.of(context).size.height * .05,
        width: 120,
        textColor: Colors.blue,
        borderColor: Colors.blue,
        boxColor: Colors.white,
        fct: () async {
          Navigator.pop(context, null);
        },
      ),
    ];

    // Add Create & Another Button only if showCreateAnother is true
    if (widget.showCreateAnother) {
      buttons.addAll([
        const SizedBox(width: 10),
        CustomRoundButton(
          title: "Create & Another",
          fontSize: FontSize.s12,
          height: MediaQuery.of(context).size.height * .05,
          width: 150,
          textColor: Colors.white,
          borderColor: ColorManager.kPrimaryColor,
          boxColor: ColorManager.kPrimaryColor,
          fct: () async {
            if (_formKey.currentState!.validate()) {
              await _submitForm(accessToken, createAnother: true);
            }
          },
        ),
      ]);
    }

    buttons.addAll([
      const SizedBox(width: 10),
      // Create Button
      CustomRoundButton(
        title: "Create Supplier",
        fontSize: FontSize.s12,
        height: MediaQuery.of(context).size.height * .05,
        width: 140,
        fct: () async {
          if (_formKey.currentState!.validate()) {
            await _submitForm(accessToken, createAnother: false);
          }
        },
      ),
    ]);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: buttons,
    );
  }

Future<void> _submitForm(String? accessToken,
    {required bool createAnother}) async {
  // Require payment type before submit
  if (selectedPaymentType == PaymentType.none) {
    showScaffoldError(context: context, message: "Please select a payment type");
    return;
  }

  // Validate required fields
  if (nameTextController.text.trim().isEmpty) {
    showScaffoldError(context: context, message: "Name is required");
    return;
  }

  if (phoneNumberController.text.trim().isEmpty) {
    showScaffoldError(context: context, message: "Phone number is required");
    return;
  }

  // Show loading indicator
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) =>
        const Center(child: CircularProgressIndicator.adaptive()),
  );

  try {
    // Prepare payment status string
    String paymentStatus = '';
    if (selectedPaymentType == PaymentType.toPay) {
      paymentStatus = 'to_pay';
    } else if (selectedPaymentType == PaymentType.toReceive) {
      paymentStatus = 'to_receive';
    }

    // Debug log the data being sent
    debugPrint('Submitting supplier with data:');
    debugPrint('Name: ${nameTextController.text}');
    debugPrint('Email: ${emailTextController.text}');
    debugPrint('Phone: ${phoneNumberController.text.replaceAll("-", "")}');
    debugPrint('Balance: ${balanceTextController.text}');
    debugPrint('Payment Status: $paymentStatus');
    debugPrint('Address: ${addressTextController.text}');
    debugPrint('Alt Phone: ${altPhoneNumberController.text.replaceAll("-", "")}');
    debugPrint('Product Categories: ${selectedCategories.map((c) => c.categoryId!).toList()}');

    final result = await SupplierProvider().addSupplier(
      name: nameTextController.text.trim(),
      email: emailTextController.text.trim(),
      phone: phoneNumberController.text.replaceAll("-", ""),
      accessToken: accessToken ?? "",
      balance: balanceTextController.text.trim(),
      paymentStatus: paymentStatus,
      address: addressTextController.text.trim(),
      altPhone: altPhoneNumberController.text.replaceAll("-", ""),
      productCategories: selectedCategories.map((c) => c.categoryId!).toList(),
    );

    // Close loading dialog
    Navigator.pop(context);

    debugPrint('Supplier creation result: $result');
    debugPrint('Supplier creation result type: ${result.runtimeType}');
    debugPrint('Supplier creation result keys: ${result.keys.toList()}');

    // Safely cast the result to ensure proper type handling
    final Map<String, dynamic> safeResult = Map<String, dynamic>.from(result);

    if (safeResult["status"] == "success") {
      showScaffold(context: context, message: '${safeResult["message"]}');

      if (createAnother) {
        _clearFields();
      } else {
        Navigator.pop(context, {
          "status": "success",
          "name": nameTextController.text,
          "phone": phoneNumberController.text.replaceAll("-", ""),
          "response": safeResult,
        });
      }
    } else {
      // Handle backend validation errors
      final dynamic errorsData = safeResult['errors'];
      Map<String, dynamic> errorResponse = {};
      
      if (errorsData != null) {
        try {
          if (errorsData is Map) {
            errorResponse = Map<String, dynamic>.from(errorsData);
          }
        } catch (e) {
          debugPrint('Error parsing errors data: $e');
        }
      }
      
      if (errorResponse.isNotEmpty) {
        final errorMsg = errorResponse.values
            .map((e) {
              if (e is List) {
                return e.join(', ');
              } else {
                return e.toString();
              }
            })
            .join('\n');
        showScaffoldError(context: context, message: errorMsg);
      } else {
        showScaffoldError(
            context: context,
            message: safeResult['message']?.toString() ?? "An unknown error occurred");
      }
    }
  } catch (error) {
    Navigator.pop(context);
    debugPrint('Error in _submitForm: $error');
    showScaffoldError(
        context: context, message: 'Error adding supplier: $error');
  }
}

void _clearFields() {
  if (mounted) {
    setState(() {
      nameTextController.clear();
      emailTextController.clear();
      phoneNumberController.clear();
      altPhoneNumberController.clear();
      addressTextController.clear();
      balanceTextController.text = '0.00';
      selectedPaymentType = PaymentType.none;
      selectedCategories.clear();
      categorySearchController.clear();
    });
  }
}

String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return null; // Email is optional
  }
  const pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$";
  final regex = RegExp(pattern);
  return !regex.hasMatch(value) ? 'Enter a valid email address' : null;
}

String? validatePhoneNumber(String? value) {
  if (value == null || value.isEmpty) {
    return 'Phone number is required';
  }
  // Check if the phone number is valid
  final phoneNumber = value.replaceAll("-", ""); // Remove formatting
  if (phoneNumber.length < 10) {
    return 'Enter a valid phone number';
  }
  return null; // Return null if there are no errors
}
}

class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String formattedText = formatPhoneNumber(newValue.text);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }

  String formatPhoneNumber(String input) {
    input =
        input.replaceAll(RegExp(r'\D'), ''); // Remove non-numeric characters
    if (input.length > 3) {
      input = '${input.substring(0, 3)}-${input.substring(3)}';
    }
    if (input.length > 7) {
      input = '${input.substring(0, 7)}-${input.substring(7)}';
    }
    return input;
  }
}

