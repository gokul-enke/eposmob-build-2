import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_executive_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/screens/customers/add_customer_modal.dart';

class CustomerInput extends StatefulWidget {
  final Size size;
  final GlobalKey autocompletePhoneKey;
  const CustomerInput(
      {super.key, required this.size, required this.autocompletePhoneKey});

  @override
  State<CustomerInput> createState() => _CustomerInputState();
}

class _CustomerInputState extends State<CustomerInput> {
  @override
  Widget build(BuildContext context) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            (billingProvider.mobileNumberText != "" &&
                    !billingProvider.isCustomerManuallySelected &&
                    Provider.of<LocalProductProvider>(context, listen: false)
                            .currentOrder ==
                        null)
                ? Expanded(
                    child: buildColumnWidgetForTextFields(
                      controller: billingProvider.mobileNumberTextController,
                      readOnly: true,
                      size: widget.size,
                      hintText: 'billing.phone_number_hint'.tr,
                    ),
                  )
                : Expanded(
                    child: BuildBoxShadowContainer(
                      circleRadius: 7,
                      alignment: Alignment.centerLeft,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 0),
                      padding: const EdgeInsets.only(left: 15),
                      height: widget.size.height * .07,
                      width: widget.size.width / 3,
                      child: Autocomplete<CustomerListModelData>(
                        key: widget.autocompletePhoneKey,
                        initialValue: TextEditingValue(
                            text:
                                billingProvider.mobileNumberText?.isNotEmpty ==
                                        true
                                    ? billingProvider.mobileNumberText!
                                    : ""),
                        optionsBuilder: (mobileNumberTextController) async {
                          if (mobileNumberTextController.text.isEmpty) {
                            setState(() {
                              billingProvider.setHighlightedCustomerIndex(null);
                            });
                            return const Iterable<
                                CustomerListModelData>.empty();
                          }

                          String? accessToken =
                              Provider.of<AuthModel>(context, listen: false)
                                  .token;

                          try {
                            dynamic response;
                            if (RegExp(r'^[0-9]+$')
                                .hasMatch(mobileNumberTextController.text)) {
                              response = await CustomerProvider()
                                  .findCustomerByPhone(accessToken ?? "",
                                      mobileNumberTextController.text, context);
                            } else {
                              response = await CustomerProvider()
                                  .findCustomerByName(accessToken ?? "",
                                      mobileNumberTextController.text, context);
                            }

                            if (response["status"] == "success") {
                              CustomerListModel customerListModel =
                                  CustomerListModel.fromJson(response);
                              List<CustomerListModelData>?
                                  filteredCustomerList = customerListModel.data;

                              billingProvider.setCurrentCustomerOptions(
                                  filteredCustomerList ?? []);
                              final nonNullList = filteredCustomerList ??
                                  const <CustomerListModelData>[];
                              return nonNullList.isNotEmpty
                                  ? nonNullList
                                  : const Iterable<
                                      CustomerListModelData>.empty();
                            }
                          } catch (_) {}

                          setState(() {
                            billingProvider.setCurrentCustomerOptions([]);
                          });
                          return const Iterable<CustomerListModelData>.empty();
                        },
                        displayStringForOption:
                            (CustomerListModelData customer) =>
                                "${customer.name} ${customer.phone}",
                        onSelected: (CustomerListModelData selection) {
                          Provider.of<CustomerSelectionProvider>(context,
                                  listen: false)
                              .setSelectedCustomer(selection);

                          String? accessToken =
                              Provider.of<AuthModel>(context, listen: false)
                                  .token;
                          Provider.of<CartProvider>(context, listen: false)
                              .fetchCartDataFromApi(
                                  customerId: selection.id ?? 0,
                                  accessToken: accessToken ?? '');

                          setState(() {
                            billingProvider.setMobileNumberText("");
                            billingProvider.setSelectedCustomer(selection,
                                isManual: true);
                            billingProvider.mobileNumberTextController.text =
                                "${selection.name} ${selection.phone}";
                          });
                        },
                        fieldViewBuilder: (
                          BuildContext context,
                          TextEditingController autoCompleteController,
                          FocusNode focusNode,
                          VoidCallback onFieldSubmitted,
                        ) {
                          // Sync the autocomplete controller text from provider when needed
                          // Keep autocomplete controller in sync with provider **only when the field is NOT actively being edited**.
                          if (!focusNode.hasFocus &&
                              autoCompleteController.text !=
                                  (billingProvider.mobileNumberText ?? '')) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              autoCompleteController.text =
                                  billingProvider.mobileNumberText ?? '';
                              autoCompleteController.selection =
                                  TextSelection.collapsed(
                                      offset:
                                          autoCompleteController.text.length);
                            });
                          }

                          void ensureFocus() {
                            if (!focusNode.hasFocus) {
                              focusNode.requestFocus();
                            }
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              autoCompleteController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: autoCompleteController.text.length),
                              );
                            });
                          }

                          autoCompleteController.removeListener(ensureFocus);
                          autoCompleteController.addListener(ensureFocus);

                          return KeyboardListener(
                            focusNode:
                                billingProvider.customerTextFieldFocusNode,
                            onKeyEvent: (KeyEvent event) {
                              if (event is KeyDownEvent) {
                                if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowDown) {
                                  setState(() {
                                    billingProvider.navigateCustomerDown();
                                  });
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    billingProvider
                                        .scrollToHighlightedCustomer();
                                  });
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.arrowUp) {
                                  setState(() {
                                    billingProvider.navigateCustomerUp();
                                  });
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    billingProvider
                                        .scrollToHighlightedCustomer();
                                  });
                                } else if (event.logicalKey ==
                                    LogicalKeyboardKey.enter) {
                                  if (billingProvider
                                              .highlightedCustomerIndex !=
                                          null &&
                                      billingProvider
                                          .currentCustomerOptions.isNotEmpty &&
                                      billingProvider
                                              .highlightedCustomerIndex! <
                                          billingProvider
                                              .currentCustomerOptions.length) {
                                    final selectedCust =
                                        billingProvider.currentCustomerOptions[
                                            billingProvider
                                                .highlightedCustomerIndex!];

                                    String? accessToken =
                                        Provider.of<AuthModel>(context,
                                                listen: false)
                                            .token;
                                    Provider.of<CartProvider>(context,
                                            listen: false)
                                        .fetchCartDataFromApi(
                                            customerId: selectedCust.id ?? 0,
                                            accessToken: accessToken ?? '');

                                    autoCompleteController.text =
                                        "${selectedCust.name} ${selectedCust.phone}";
                                    billingProvider
                                            .mobileNumberTextController.text =
                                        "${selectedCust.name} ${selectedCust.phone}";

                                    setState(() {
                                      billingProvider.setMobileNumberText("");
                                      billingProvider.setSelectedCustomer(
                                          selectedCust,
                                          isManual: true);
                                    });

                                    focusNode.unfocus();
                                  }
                                }
                              }
                            },
                            child: TextField(
                              onTap: () {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (autoCompleteController.text.isNotEmpty &&
                                      focusNode.hasFocus) {
                                    autoCompleteController.selection =
                                        TextSelection(
                                      baseOffset: 0,
                                      extentOffset:
                                          autoCompleteController.text.length,
                                    );
                                  }
                                });

                                Provider.of<AppSettingsProvider>(context,
                                    listen: false); // ensure provider exists
                              },
                              controller: autoCompleteController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'billing.enter_mobile_number'.tr,
                                hintStyle: buildCustomStyle(
                                  FontWeight.w500,
                                  12,
                                  0.27,
                                  Colors.grey.withValues(alpha: 0.5),
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10.0),
                                suffixIconConstraints: const BoxConstraints(
                                    maxHeight: 25, maxWidth: 30),
                                suffixIcon: (billingProvider.isCustomerFound ||
                                        billingProvider.selectedCustomerID !=
                                            null)
                                    ? const Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: Icon(
                                          Icons.check_circle,
                                          color: ColorManager.kButtonGreen,
                                          size: 25,
                                        ),
                                      )
                                    : null,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  billingProvider.setMobileNumberText(value);
                                  billingProvider.clearSelectedCustomer();
                                  billingProvider
                                      .setHighlightedCustomerIndex(null);
                                  billingProvider
                                      .mobileNumberTextController.text = value;
                                });
                              },
                              style: buildCustomStyle(
                                FontWeight.w500,
                                12,
                                0.27,
                                Colors.black.withValues(alpha: 0.5),
                              ),
                            ),
                          );
                        },
                        optionsViewBuilder: (
                          BuildContext context,
                          AutocompleteOnSelected<CustomerListModelData>
                              onSelected,
                          Iterable<CustomerListModelData> options,
                        ) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              child: Container(
                                width: MediaQuery.of(context).size.width / 3,
                                color: Colors.white,
                                constraints:
                                    const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  controller:
                                      billingProvider.customerScrollController,
                                  padding: const EdgeInsets.all(8.0),
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: options.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final CustomerListModelData option =
                                        options.elementAt(index);
                                    final bool isHighlighted = billingProvider
                                            .highlightedCustomerIndex ==
                                        index;

                                    return MouseRegion(
                                      onEnter: (_) {
                                        setState(() {
                                          billingProvider.hoverMap[index] =
                                              true;
                                          billingProvider
                                              .setHighlightedCustomerIndex(
                                                  index);
                                        });
                                      },
                                      onExit: (_) {
                                        setState(() {
                                          billingProvider.hoverMap[index] =
                                              false;
                                        });
                                      },
                                      child: GestureDetector(
                                        onTap: () {
                                          onSelected(option);
                                        },
                                        child: Container(
                                          color: isHighlighted
                                              ? Colors.blue.shade50
                                              : (billingProvider
                                                          .hoverMap[index] ==
                                                      true
                                                  ? Colors.grey[200]
                                                  : Colors.white),
                                          child: ListTile(
                                            title: Text(
                                              "${option.name} ${option.phone}",
                                              style: buildCustomStyle(
                                                FontWeight.w500,
                                                12,
                                                0.27,
                                                isHighlighted
                                                    ? Colors.blue.shade800
                                                    : Colors.black
                                                        .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            hoverColor: Colors.grey[200],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            const SizedBox(width: 10),
            Row(
              children: [
                // Plus button - only show when no customer is selected
                if (billingProvider.selectedCustomerID == null &&
                    !billingProvider.isCustomerFound) ...[
                  BuildBoxShadowContainer(
                    height: widget.size.height * .07,
                    width: 50,
                    circleRadius: 5,
                    child: InkWell(
                      onTap: () async {
                        final result = await showAddCustomerModal(
                          context,
                          widget.size,
                          mobileNumber:
                              billingProvider.mobileNumberTextController.text,
                        );
                        if (result != null &&
                            result is Map &&
                            result['status'] == 'success') {
                          final createdPhone =
                              (result['phone'] ?? '').toString();
                          final createdName = (result['name'] ?? '').toString();
                          try {
                            String? accessToken =
                                Provider.of<AuthModel>(context, listen: false)
                                    .token;
                            final response = await CustomerProvider()
                                .findCustomerByPhone(
                                    accessToken ?? '', createdPhone, context);
                            if (!mounted) return;
                            if (response != null &&
                                response['status'] == 'success') {
                              final listModel =
                                  CustomerListModel.fromJson(response);
                              final list = listModel.data ?? [];
                              if (list.isNotEmpty) {
                                final selection = list.first;
                                Provider.of<CustomerSelectionProvider>(context,
                                        listen: false)
                                    .setSelectedCustomer(selection);
                                setState(() {
                                  billingProvider.setMobileNumberText(
                                      "${selection.name} ${selection.phone}");
                                  billingProvider.setSelectedCustomer(selection,
                                      isManual: true);
                                  billingProvider
                                          .mobileNumberTextController.text =
                                      "${selection.name} ${selection.phone}";
                                });
                              } else {
                                setState(() {
                                  billingProvider.setMobileNumberText(
                                      "$createdName $createdPhone".trim());
                                  billingProvider
                                          .mobileNumberTextController.text =
                                      "$createdName $createdPhone".trim();
                                });
                              }
                            }
                          } catch (_) {
                            setState(() {
                              billingProvider.setMobileNumberText(
                                  "$createdName $createdPhone".trim());
                              billingProvider.mobileNumberTextController.text =
                                  "$createdName $createdPhone".trim();
                            });
                          }
                        }
                      },
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          size: 27,
                          color: ColorManager.kButtonGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Close button - always show
                BuildBoxShadowContainer(
                  height: widget.size.height * .07,
                  width: 50,
                  circleRadius: 5,
                  child: InkWell(
                    onTap: () {
                      Provider.of<CustomerSelectionProvider>(context,
                              listen: false)
                          .clearSelectedCustomer();
                      setState(() {
                        billingProvider.mobileNumberTextController.clear();
                        billingProvider.setMobileNumberText("");
                        billingProvider.clearSelectedCustomer();
                      });
                    },
                    child: const Center(
                      child: Icon(
                        Icons.close,
                        size: 27,
                        color: ColorManager.kButtonRed,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Customer Balance Display
        if (billingProvider.selectedCustomer?.balance != null &&
            _shouldShowCustomerBalance(context))
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 5.0),
            child: _buildCustomerBalance(
                context, billingProvider.selectedCustomer!.balance!),
          ),
      ],
    );
  }

  bool _shouldShowCustomerBalance(BuildContext context) {
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    if (billingProvider.selectedCustomer?.phone == null) return false;

    final salesExecutiveProvider =
        Provider.of<SalesExecutiveProvider>(context, listen: false);
    final currentExecutive = salesExecutiveProvider.getCurrentUser(context);
    if (currentExecutive?.phone != null &&
        billingProvider.selectedCustomer!.phone == currentExecutive!.phone) {
      return false;
    }
    return true;
  }

  Widget _buildCustomerBalance(BuildContext context, double balance) {
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final currency = appSettingsProvider.appSettings?.currency ?? '';
    Color balanceColor;
    String balanceText;

    if (balance > 0) {
      balanceColor = Colors.green;
      balanceText = "+${balance.toStringAsFixed(2)}";
    } else if (balance < 0) {
      balanceColor = Colors.red;
      balanceText = balance.toStringAsFixed(2);
    } else {
      balanceColor = Colors.black;
      balanceText = balance.toStringAsFixed(2);
    }

    return Row(
      children: [
        Text(
          'Customer Balance: ',
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.14,
            Colors.grey.shade600,
          ),
        ),
        Text(
          '$currency $balanceText',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s12,
            0.14,
            balanceColor,
          ),
        ),
      ],
    );
  }
}
