import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/newcomponents/custom_dropdown_with_search.dart';
import 'package:pos_machine/newcomponents/custom_round_button.dart';
import 'package:pos_machine/newcomponents/custom_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/models/get_users.dart';
import 'package:provider/provider.dart';

class CreateNewVoucherScreen extends StatefulWidget {
  const CreateNewVoucherScreen({Key? key}) : super(key: key);

  @override
  _CreateNewVoucherScreenState createState() => _CreateNewVoucherScreenState();
}

class _CreateNewVoucherScreenState extends State<CreateNewVoucherScreen> {
  // Controllers
  final TextEditingController _paymentRefController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _particularsController = TextEditingController();

  // Focus Nodes
  final FocusNode _accountTypeFocus = FocusNode();
  final FocusNode _paymentMethodFocus = FocusNode();
  final FocusNode _paymentRefFocus = FocusNode();
  final FocusNode _amountFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  final FocusNode _commentFocus = FocusNode();
  final FocusNode _particularsFocus = FocusNode();

  // Selected values
  String? _selectedAccountType;
  String? _selectedPaymentMethod;
  String? _selectedUserId;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _paymentRefController.dispose();
    _amountController.dispose();
    _commentController.dispose();
    _particularsController.dispose();

    _accountTypeFocus.dispose();
    _paymentMethodFocus.dispose();
    _paymentRefFocus.dispose();
    _amountFocus.dispose();
    _toFocus.dispose();
    _commentFocus.dispose();
    _particularsFocus.dispose();

    super.dispose();
  }

  // Helper method to build labels
  Widget _buildLabel(String text, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: buildCustomStyle(
          FontWeightManager.medium,
          FontSize.s14,
          0.27,
          ColorManager.textColor,
        ),
        children: isRequired
            ? [
                TextSpan(
                  text: '*',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s14,
                    0.27,
                    Colors.red,
                  ),
                ),
              ]
            : [],
      ),
    );
  }

  // Helper method to build text fields
  Widget _buildTextField(
    String label,
    TextEditingController controller,
    TextInputType keyboardType,
    Size size, {
    bool isRequired = false,
    String? placeholder,
    FocusNode? focusNode,
    bool readOnly = false,
    int maxLines = 1,
    TextInputAction? textInputAction,
    Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        const SizedBox(height: 4),
        Container(
          height: maxLines > 1 ? null : 48,
          decoration: BoxDecoration(
            color: readOnly ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            readOnly: readOnly,
            maxLines: maxLines,
            textInputAction: textInputAction,
            onFieldSubmitted: onFieldSubmitted,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.27,
              ColorManager.textColor,
            ),
            decoration: InputDecoration(
              hintText: placeholder ?? label,
              hintStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.27,
                Colors.grey.shade400,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            validator: validator ??
                (isRequired
                    ? (value) {
                        if (value == null || value.isEmpty) {
                          return 'This field is required';
                        }
                        return null;
                      }
                    : null),
            inputFormatters: keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
          ),
        ),
      ],
    );
  }

  // Submit voucher
  void _submitVoucher() async {
    if (!_formKey.currentState!.validate()) {
      showScaffold(
        context: context,
        message: 'Please fill all required fields',
      );
      return;
    }

    if (_selectedAccountType == null ||
        _selectedPaymentMethod == null ||
        _selectedUserId == null) {
      showScaffold(
        context: context,
        message: 'Please select all required fields',
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator.adaptive(),
      ),
    );

    final invoiceProvider =
        Provider.of<InvoiceProvider>(context, listen: false);
    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? "";

    final result = await invoiceProvider.addVoucher(
      comment: _commentController.text,
      particular: _particularsController.text,
      accountType: _selectedAccountType ?? "",
      paymentMethod: _selectedPaymentMethod ?? "",
      paymentMethodRef: _paymentRefController.text,
      amount: _amountController.text,
      toUserID: _selectedUserId ?? "",
      type: "voucher",
      accessToken: accessToken,
    );

    Navigator.pop(context); // Close loading

    final sideBarController = Get.put(SideBarController());

    if (result["status"] == "success") {
      showScaffold(context: context, message: result["message"]);
      sideBarController.index.value = 22;
    } else {
      showScaffold(context: context, message: result["message"]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    final paymentList = invoiceProvider.getPaymentType;
    final voucherAccountTypes = invoiceProvider.getVoucherAccountTypes;
    final usersList = invoiceProvider.getUsersList;
    final sideBarController = Get.put(SideBarController());

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => sideBarController.index.value = 22,
                          icon: const Icon(Icons.arrow_back_ios),
                          iconSize: 20,
                        ),
                        Text(
                          'Create New Voucher',
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.30,
                            ColorManager.textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Main Form Container
                CustomBoxShadowContainer(
                  circleRadius: 12,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Account Type & Payment Method
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Account Type", isRequired: true),
                                const SizedBox(height: 4),
                                CustomDropDownWithSearch<String>(
                                  hintText: "Select account type",
                                  title: "",
                                  value: _selectedAccountType,
                                  items:
                                      voucherAccountTypes?.keys.toList() ?? [],
                                  focusNode: _accountTypeFocus,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAccountType = value;
                                    });
                                    FocusScope.of(context)
                                        .requestFocus(_paymentMethodFocus);
                                  },
                                  displayText: (item) =>
                                      voucherAccountTypes?[item] ?? item,
                                  showName: false,
                                  height: 48,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("Payment Method", isRequired: true),
                                const SizedBox(height: 4),
                                CustomDropDownWithSearch<String>(
                                  hintText: "Select payment method",
                                  title: "",
                                  value: _selectedPaymentMethod,
                                  items: paymentList?.keys.toList() ?? [],
                                  focusNode: _paymentMethodFocus,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPaymentMethod = value;
                                    });
                                    FocusScope.of(context)
                                        .requestFocus(_paymentRefFocus);
                                  },
                                  displayText: (item) =>
                                      paymentList?[item] ?? item,
                                  showName: false,
                                  height: 48,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 2: Payment Ref & Amount
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              "Payment Reference",
                              _paymentRefController,
                              TextInputType.text,
                              size,
                              isRequired: true,
                              placeholder: "Enter reference",
                              focusNode: _paymentRefFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context)
                                    .requestFocus(_amountFocus);
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              "Amount",
                              _amountController,
                              TextInputType.number,
                              size,
                              isRequired: true,
                              placeholder: "0.00",
                              focusNode: _amountFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context).requestFocus(_toFocus);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 3: To (User) & Comment
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel("To", isRequired: true),
                                const SizedBox(height: 4),
                                CustomDropDownWithSearch<String>(
                                  hintText: "Select user",
                                  title: "",
                                  value: _selectedUserId,
                                  items: usersList
                                          ?.map((u) => u.id.toString())
                                          .toSet()
                                          .toList() ??
                                      [],
                                  focusNode: _toFocus,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedUserId = value;
                                    });
                                    FocusScope.of(context)
                                        .requestFocus(_commentFocus);
                                  },
                                  displayText: (item) {
                                    final user = usersList?.firstWhere(
                                      (u) => u.id.toString() == item,
                                      orElse: () =>
                                          GetUsersModelData(id: 0, name: ""),
                                    );
                                    return user?.name ?? "Unknown";
                                  },
                                  showName: false,
                                  height: 48,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              "Comment",
                              _commentController,
                              TextInputType.text,
                              size,
                              placeholder: "Optional comment",
                              focusNode: _commentFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) {
                                FocusScope.of(context)
                                    .requestFocus(_particularsFocus);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 4: Particulars (full width)
                      _buildTextField(
                        "Particulars",
                        _particularsController,
                        TextInputType.text,
                        size,
                        placeholder: "Enter particulars",
                        focusNode: _particularsFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          _submitVoucher();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CustomRoundButtonAdvanced(
                      title: "Cancel",
                      fct: () => sideBarController.index.value = 22,
                      width: 120,
                      height: 45,
                      fontSize: 14,
                      boxColor: Colors.white,
                      textColor: ColorManager.kPrimaryColor,
                      borderColor: ColorManager.kPrimaryColor,
                    ),
                    const SizedBox(width: 12),
                    CustomRoundButtonAdvanced(
                      title: "Submit",
                      fct: _submitVoucher,
                      width: 120,
                      height: 45,
                      fontSize: 14,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
