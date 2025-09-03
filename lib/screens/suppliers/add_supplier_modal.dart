import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_dropdown_with_search.dart';
import 'package:pos_machine/components/build_multiselect_dropdown.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:provider/provider.dart';

import '../../components/build_container_box.dart';
import '../../components/build_round_button.dart';
import '../../components/build_title.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

Future<dynamic> showAddSupplierModal(BuildContext context, Size size) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: const AddSupplierModal(),
        ),
      );
    },
  );
}

class AddSupplierModal extends StatefulWidget {
  const AddSupplierModal({Key? key}) : super(key: key);

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

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10.0, bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add New Supplier',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name, Email
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Name",
                        nameTextController,
                        TextInputType.text,
                        size,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Email Address",
                        emailTextController,
                        TextInputType.emailAddress,
                        size,
                        validator: validateEmail,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Row 2: Phone, Alt Phone
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Phone Number",
                        phoneNumberController,
                        TextInputType.number,
                        size,
                        inputFormatter: PhoneNumberFormatter(),
                        validator: validatePhoneNumber,
                        isRequired: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Alternative Phone",
                        altPhoneNumberController,
                        TextInputType.number,
                        size,
                        inputFormatter: PhoneNumberFormatter(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Row 3: Address, Balance
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        "Address",
                        addressTextController,
                        // hint: 'address',
                        TextInputType.text,
                        size,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTextField(
                        "Balance",
                        balanceTextController,
                        TextInputType.numberWithOptions(decimal: true),
                        size,
                        inputFormatter: FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Row 4: Product Categories Dropdown
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryMultiSelect(context, size),
                    ),
                  ],
                ),
                const SizedBox(height: 15),

                // Row 5: Payment Radio Buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                      child: Text(
                        "Payment",
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s16,
                          0.27,
                          ColorManager.textColor,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRadioOption(
                            "To Pay",
                            PaymentType.toPay,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildRadioOption(
                            "To Receive",
                            PaymentType.toReceive,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                _buildActionButtons(size, accessToken),
                const SizedBox(height: 25),
              ],
            ),
          ],
        ),
      ),
    );
  }

Widget _buildCategoryMultiSelect(BuildContext context, Size size) {
  final categoryProvider = Provider.of<CategoryProvider>(context);
  final categories = categoryProvider.category ?? [];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text(
          "Product Categories",
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s16,
            0.27,
            ColorManager.textColor,
          ),
        ),
      ),
      BuildMultiSelectDropDownWithSearch<Category>(
        hintText: "Select Categories",
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
  );
}


  Widget _buildTextField(String title, TextEditingController controller,
      TextInputType keyboardType, Size size,
      {FormFieldValidator<String>? validator,
      TextInputFormatter? inputFormatter,
      bool isRequired = false,
      String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BuildTextTile(
              title: title,
              textStyle: buildCustomStyle(FontWeightManager.regular,
                  FontSize.s14, 0.27, Colors.black.withOpacity(0.6)),
            ),
            if (isRequired)
              Text(
                ' *',
                style: buildCustomStyle(
                    FontWeightManager.regular, FontSize.s14, 0.27, Colors.red),
              ),
          ],
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
          width: size.width,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatter != null ? [inputFormatter] : null,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.27,
                Colors.grey,
              ),
            ),
            validator: validator ??
                (isRequired
                    ? (value) {
                        if (value == null || value.isEmpty) {
                          return '$title is required';
                        }
                        return null;
                      }
                    : null),
            style: buildCustomStyle(FontWeightManager.medium, FontSize.s12,
                0.27, ColorManager.textColor.withOpacity(.5)),
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
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.black.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(Size size, String? accessToken) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Close Button
          CustomRoundButton(
            title: "Close",
            fct: () {
              Navigator.pop(context);
            },
            height: 50,
            width: 120,
            fontSize: FontSize.s12,
            textColor: Colors.blue,
            borderColor: Colors.blue,
            boxColor: Colors.white,
          ),
          const SizedBox(width: 10),
          // Create & Another Button
          CustomRoundButton(
            title: "Create & Another",
            fct: () async {
              if (_formKey.currentState!.validate()) {
                await _submitForm(accessToken, createAnother: true);
              }
            },
            height: 50,
            width: 150,
            fontSize: FontSize.s12,
            textColor: Colors.white,
            borderColor: ColorManager.kPrimaryColor,
            boxColor: ColorManager.kPrimaryColor,
          ),
          const SizedBox(width: 10),
          // Create Button
          CustomRoundButton(
            title: "Create",
            fct: () async {
              if (_formKey.currentState!.validate()) {
                await _submitForm(accessToken, createAnother: false);
              }
            },
            height: 50,
            width: 120,
            fontSize: FontSize.s12,
          ),
        ],
      ),
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

