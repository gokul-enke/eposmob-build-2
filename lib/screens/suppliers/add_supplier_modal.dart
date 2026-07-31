import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/category_list.dart';
import 'package:pos_machine/models/supplier.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/supplier_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';

Future<dynamic> showAddSupplierModal(BuildContext context, Size size,
    {bool showCreateAnother = true}) {
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
            maxWidth: size.width < 700 ? size.width * 0.95 : size.width / 2,
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

  const AddSupplierModal({Key? key, this.showCreateAnother = true})
      : super(key: key);

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
  final taxNumberController = TextEditingController();
  final crNumberController = TextEditingController();
  final vatNumberController = TextEditingController();
  final categorySearchController = TextEditingController();
  final balanceTextController = TextEditingController();

  PaymentType selectedPaymentType = PaymentType.toPay;
  List<Category> selectedCategories = [];

  bool isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    balanceTextController.text = '0.00';
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
      await categoryProvider.ensureCategoriesLoaded();
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
    final isMobile = size.width < 700;
    final fieldWidth = isMobile ? double.infinity : size.width / 4.5;
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
          isMobile
              ? Column(children: [
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
                      onchanged: (value) {},
                      hintText: 'Supplier Name',
                      size: size,
                      width: fieldWidth),
                  const SizedBox(height: 12),
                  buildColumnWidgetForTextFields(
                      autofocus: true,
                      controller: emailTextController,
                      keyboardType: TextInputType.emailAddress,
                      validator: validateEmail,
                      onchanged: (value) {},
                      hintText: 'Email Address',
                      size: size,
                      width: fieldWidth),
                ])
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                          onchanged: (value) {},
                          hintText: 'Supplier Name',
                          size: size,
                          width: size.width / 4.5),
                      buildColumnWidgetForTextFields(
                          autofocus: true,
                          controller: emailTextController,
                          keyboardType: TextInputType.emailAddress,
                          validator: validateEmail,
                          onchanged: (value) {},
                          hintText: 'Email Address',
                          size: size,
                          width: size.width / 4.5),
                    ]),
          const SizedBox(height: 16),

          // Row 2: Phone, Alt Phone
          isMobile
              ? Column(children: [
                  buildColumnWidgetForTextFields(
                      autofocus: true,
                      isStarRed: true,
                      controller: phoneNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [PhoneNumberFormatter()],
                      validator: validatePhoneNumber,
                      onchanged: (value) {},
                      hintText: 'Phone Number',
                      size: size,
                      width: fieldWidth),
                  const SizedBox(height: 12),
                  buildColumnWidgetForTextFields(
                      autofocus: true,
                      controller: altPhoneNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [PhoneNumberFormatter()],
                      onchanged: (value) {},
                      hintText: 'Alternative Phone',
                      size: size,
                      width: fieldWidth),
                ])
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      buildColumnWidgetForTextFields(
                          autofocus: true,
                          isStarRed: true,
                          controller: phoneNumberController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [PhoneNumberFormatter()],
                          validator: validatePhoneNumber,
                          onchanged: (value) {},
                          hintText: 'Phone Number',
                          size: size,
                          width: size.width / 4.5),
                      buildColumnWidgetForTextFields(
                          autofocus: true,
                          controller: altPhoneNumberController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [PhoneNumberFormatter()],
                          onchanged: (value) {},
                          hintText: 'Alternative Phone',
                          size: size,
                          width: size.width / 4.5),
                    ]),
          const SizedBox(height: 16),

          // Row 3: Address, Tax Number
          isMobile
              ? Column(children: [
                  buildColumnWidgetForTextFields(
                      autofocus: true,
                      controller: addressTextController,
                      onchanged: (value) {},
                      hintText: 'Address',
                      size: size,
                      width: fieldWidth),
                  const SizedBox(height: 12),
                  buildColumnWidgetForTextFields(
                      autofocus: true,
                      controller: taxNumberController,
                      onchanged: (value) {},
                      hintText: 'Tax Number',
                      size: size,
                      width: fieldWidth),
                ])
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                      buildColumnWidgetForTextFields(
                          autofocus: true,
                          controller: addressTextController,
                          onchanged: (value) {},
                          hintText: 'Address',
                          size: size,
                          width: size.width / 4.5),
                      buildColumnWidgetForTextFields(
                          autofocus: true,
                          controller: taxNumberController,
                          onchanged: (value) {},
                          hintText: 'Tax Number',
                          size: size,
                          width: size.width / 4.5),
                    ]),
          const SizedBox(height: 16),

          // Row 4: Opening Balance, Payment Type
          isMobile
              ? Column(
                  children: [
                    _buildBalanceField(size, fieldWidth),
                    const SizedBox(height: 16),
                    _buildPaymentSection(size),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildBalanceField(size, double.infinity)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildPaymentSection(size)),
                  ],
                ),
          const SizedBox(height: 16),

          _buildKycSection(size),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category selector button - full width with Focus support for tab navigation
        Focus(
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
              return InkWell(
                onTap: () => _showCategorySelectionDialog(context, categories),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * .07,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: hasFocus
                          ? ColorManager.kPrimaryColor
                          : Colors.grey.withOpacity(0.3),
                      width: hasFocus ? 2 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: ColorManager.boxShadowColor,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedCategories.isEmpty
                              ? 'Select Categories'
                              : '${selectedCategories.length} categories selected',
                          style: TextStyle(
                            fontSize: 13,
                            color: selectedCategories.isEmpty
                                ? Colors.grey.shade500
                                : Colors.black87,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // Selected categories chips
        if (selectedCategories.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedCategories.map((cat) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ColorManager.kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: ColorManager.kPrimaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat.categoryName ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorManager.kPrimaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCategories.remove(cat);
                          });
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: ColorManager.kPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  void _showCategorySelectionDialog(
      BuildContext context, List<Category> categories) {
    final TextEditingController searchController = TextEditingController();
    final FocusNode searchFocusNode = FocusNode();
    final ScrollController scrollController = ScrollController();
    List<Category> filteredCategories = List.from(categories);
    List<Category> tempSelected = List.from(selectedCategories);
    int highlightedIndex = -1;

    // Handle arrow key navigation from search field
    searchFocusNode.onKey = (node, event) {
      if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final BuildContext? searchCtx = node.context;
        if (searchCtx != null) {
          Future.microtask(() {
            final scope = FocusScope.of(searchCtx);
            scope.nextFocus();
          });
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        // Auto-focus search field when dialog opens
        WidgetsBinding.instance.addPostFrameCallback((_) {
          searchFocusNode.requestFocus();
        });

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void filterCategories(String query) {
              setDialogState(() {
                if (query.isEmpty) {
                  filteredCategories = List.from(categories);
                } else {
                  filteredCategories = categories.where((cat) {
                    return (cat.categoryName ?? '')
                        .toLowerCase()
                        .contains(query.toLowerCase());
                  }).toList();
                }
                highlightedIndex = -1;
              });
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: 500,
                constraints: const BoxConstraints(maxHeight: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Select Categories',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close,
                                    color: Colors.grey.shade600),
                                onPressed: () {
                                  searchFocusNode.dispose();
                                  Navigator.pop(dialogContext);
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Search field with arrow key support
                          Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: TextField(
                              controller: searchController,
                              focusNode: searchFocusNode,
                              autofocus: true,
                              onChanged: filterCategories,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search categories...',
                                hintStyle: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.grey.shade500,
                                  size: 20,
                                ),
                                suffixIcon: searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          color: Colors.grey.shade500,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          searchController.clear();
                                          filterCategories('');
                                          searchFocusNode.requestFocus();
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Selection count bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      color: tempSelected.isNotEmpty
                          ? ColorManager.kPrimaryColor.withOpacity(0.08)
                          : Colors.grey.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tempSelected.isEmpty
                                ? '${categories.length} categories available'
                                : '${tempSelected.length} selected',
                            style: TextStyle(
                              fontSize: 13,
                              color: tempSelected.isEmpty
                                  ? Colors.grey.shade600
                                  : ColorManager.kPrimaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (tempSelected.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  tempSelected.clear();
                                });
                              },
                              child: Text(
                                'Clear all',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: ColorManager.kPrimaryColor,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Category list
                    Flexible(
                      child: Container(
                        color: Colors.white,
                        child: filteredCategories.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No categories found',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 12),
                                itemCount: filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final category = filteredCategories[index];
                                  final isSelected =
                                      tempSelected.contains(category);

                                  return Focus(
                                    onFocusChange: (hasFocus) {
                                      if (hasFocus) {
                                        setDialogState(() {
                                          highlightedIndex = index;
                                        });
                                      }
                                    },
                                    onKey: (node, event) {
                                      if (event is! RawKeyDownEvent)
                                        return KeyEventResult.ignored;
                                      if (event.logicalKey ==
                                              LogicalKeyboardKey.enter ||
                                          event.logicalKey ==
                                              LogicalKeyboardKey.space) {
                                        setDialogState(() {
                                          if (isSelected) {
                                            tempSelected.remove(category);
                                          } else {
                                            tempSelected.add(category);
                                          }
                                        });
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            tempSelected.remove(category);
                                          } else {
                                            tempSelected.add(category);
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 3),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? ColorManager.kPrimaryColor
                                                  .withOpacity(0.08)
                                              : highlightedIndex == index
                                                  ? Colors.grey.shade100
                                                  : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? ColorManager.kPrimaryColor
                                                    .withOpacity(0.4)
                                                : highlightedIndex == index
                                                    ? Colors.grey.shade400
                                                    : Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? ColorManager.kPrimaryColor
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? ColorManager
                                                          .kPrimaryColor
                                                      : Colors.grey.shade400,
                                                  width: 2,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 14,
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                category.categoryName ??
                                                    'Unknown',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: isSelected
                                                      ? ColorManager
                                                          .kPrimaryColor
                                                      : Colors.black87,
                                                  fontWeight: isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    // Footer buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              searchFocusNode.dispose();
                              Navigator.pop(dialogContext);
                            },
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedCategories = List.from(tempSelected);
                              });
                              searchFocusNode.dispose();
                              Navigator.pop(dialogContext);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorManager.kPrimaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBalanceField(Size size, double width) {
    return buildColumnWidgetForTextFields(
      controller: balanceTextController,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
      ],
      title: 'Opening Balance',
      onchanged: (value) {},
      hintText: '0.00',
      size: size,
      width: width,
    );
  }

  Widget _buildKycSection(Size size) {
    final crField = buildColumnWidgetForTextFields(
      controller: crNumberController,
      onchanged: (value) {},
      hintText: 'CR Number',
      size: size,
      width: double.infinity,
    );
    final vatField = buildColumnWidgetForTextFields(
      controller: vatNumberController,
      onchanged: (value) {},
      hintText: 'VAT Number',
      size: size,
      width: double.infinity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KYC Information',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        size.width < 700
            ? Column(
                children: [
                  crField,
                  const SizedBox(height: 12),
                  vatField,
                ],
              )
            : Row(
                children: [
                  Expanded(child: crField),
                  const SizedBox(width: 16),
                  Expanded(child: vatField),
                ],
              ),
      ],
    );
  }

  Widget _buildPaymentSection(Size size) {
    return Column(
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
            _buildRadioOption("To Pay", PaymentType.toPay),
            const SizedBox(width: 24),
            _buildRadioOption("To Receive", PaymentType.toReceive),
          ],
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
    final isMobile = size.width < 700;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _submitForm(accessToken, createAnother: false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Create Supplier',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (widget.showCreateAnother) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  await _submitForm(accessToken, createAnother: true);
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorManager.kPrimaryColor,
                side: const BorderSide(color: ColorManager.kPrimaryColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Create & Another',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, null),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close'),
          ),
        ],
      );
    }

    List<Widget> buttons = [
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
      showScaffoldError(
          context: context, message: "Please select a payment type");
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
      debugPrint(
          'Alt Phone: ${altPhoneNumberController.text.replaceAll("-", "")}');
      debugPrint('Tax Number: ${taxNumberController.text}');
      debugPrint('CR Number: ${crNumberController.text}');
      debugPrint('VAT Number: ${vatNumberController.text}');

      final result = await SupplierProvider().addSupplier(
        name: nameTextController.text.trim(),
        email: emailTextController.text.trim(),
        phone: phoneNumberController.text.replaceAll("-", ""),
        accessToken: accessToken ?? "",
        balance: balanceTextController.text.trim(),
        paymentStatus: paymentStatus,
        address: addressTextController.text.trim(),
        altPhone: altPhoneNumberController.text.replaceAll("-", ""),
        taxNumber: taxNumberController.text.trim(),
        kyc: _buildKycEntries(),
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
          final errorMsg = errorResponse.values.map((e) {
            if (e is List) {
              return e.join(', ');
            } else {
              return e.toString();
            }
          }).join('\n');
          showScaffoldError(context: context, message: errorMsg);
        } else {
          showScaffoldError(
              context: context,
              message: safeResult['message']?.toString() ??
                  "An unknown error occurred");
        }
      }
    } catch (error) {
      Navigator.pop(context);
      debugPrint('Error in _submitForm: $error');
      showScaffoldError(
          context: context, message: 'Error adding supplier: $error');
    }
  }

  List<SupplierKyc> _buildKycEntries() {
    return [
      if (crNumberController.text.trim().isNotEmpty)
        SupplierKyc(key: 'CR_NUMBER', value: crNumberController.text.trim()),
      if (vatNumberController.text.trim().isNotEmpty)
        SupplierKyc(key: 'VAT_NUMBER', value: vatNumberController.text.trim()),
    ];
  }

  void _clearFields() {
    if (mounted) {
      setState(() {
        nameTextController.clear();
        emailTextController.clear();
        phoneNumberController.clear();
        altPhoneNumberController.clear();
        addressTextController.clear();
        taxNumberController.clear();
        crNumberController.clear();
        vatNumberController.clear();
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
