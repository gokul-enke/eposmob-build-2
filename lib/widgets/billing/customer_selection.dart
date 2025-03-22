import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:websafe_svg/websafe_svg.dart';

class CustomerSelection extends StatefulWidget {
  final String? mobileNumberText;
  final Function(String?) onMobileNumberChanged;
  final Function(int?, String?, CustomerListModelData?) onCustomerSelected;
  final TextEditingController mobileNumberTextController;
  final bool isCustomerFound;
  final int? selectedCustomerId;
  final GlobalKey autocompletePhoneKey;
  final Function() onClearCustomerDetails;

  const CustomerSelection({
    Key? key,
    this.mobileNumberText,
    required this.onMobileNumberChanged,
    required this.onCustomerSelected,
    required this.mobileNumberTextController,
    required this.isCustomerFound,
    this.selectedCustomerId,
    required this.autocompletePhoneKey,
    required this.onClearCustomerDetails,
  }) : super(key: key);

  @override
  State<CustomerSelection> createState() => _CustomerSelectionState();
}

class _CustomerSelectionState extends State<CustomerSelection> {
  Map<int, bool> hoverMap = {};

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        (widget.mobileNumberText != null &&
                widget.mobileNumberText!.isNotEmpty)
            ? Expanded(
                child: buildColumnWidgetForTextFields(
                  controller: widget.mobileNumberTextController,
                  readOnly: true,
                  size: size,
                  hintText: 'Phone Number',
                ),
              )
            : Expanded(
                child: BuildBoxShadowContainer(
                  circleRadius: 7,
                  alignment: Alignment.centerLeft,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                  padding: const EdgeInsets.only(left: 15),
                  height: size.height * .07,
                  width: size.width / 3,
                  child: Autocomplete<CustomerListModelData>(
                    key: widget.autocompletePhoneKey,
                    optionsBuilder: (mobileNumberTextController) async {
                      if (mobileNumberTextController.text.isEmpty) {
                        widget.onMobileNumberChanged(null);
                        return const Iterable<CustomerListModelData>.empty();
                      }

                      String? accessToken =
                          Provider.of<AuthModel>(context, listen: false).token;

                      try {
                        final response = await CustomerProvider()
                            .findCustomerByPhone(accessToken ?? "",
                                mobileNumberTextController.text, context);

                        if (response["status"] == "success") {
                          CustomerListModel customerListModel =
                              CustomerListModel.fromJson(response);
                          List<CustomerListModelData>? filteredCustomerList =
                              customerListModel.data;

                          return filteredCustomerList!.isNotEmpty
                              ? filteredCustomerList
                              : const Iterable<CustomerListModelData>.empty();
                        }
                      } catch (error) {
                        debugPrint('Exception caught: $error');
                      }
                      return const Iterable<
                          CustomerListModelData>.empty();
                    },
                    displayStringForOption: (CustomerListModelData customer) =>
                        "${customer.name} ${customer.phone}",
                    onSelected: (CustomerListModelData selection) {
                      String? accessToken =
                          Provider.of<AuthModel>(context, listen: false).token;
                      Provider.of<CartProvider>(context, listen: false)
                          .fetchCartDataFromApi(
                              customerId: selection.id ?? 0,
                              accessToken: accessToken ?? '');
                      widget.onCustomerSelected(
                          selection.id, selection.phone, selection);
                    },
                    fieldViewBuilder: (BuildContext context,
                        TextEditingController mobileNumberTextController,
                        FocusNode focusNode,
                        VoidCallback onFieldSubmitted) {
                      return TextField(
                        controller: mobileNumberTextController,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Enter mobile number',
                          hintStyle: buildCustomStyle(
                            FontWeight.w500,
                            12,
                            0.27,
                            Colors.grey.withOpacity(.5),
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          widget.onMobileNumberChanged(value);
                        },
                        style: buildCustomStyle(
                          FontWeight.w500,
                          12,
                          0.27,
                          Colors.black.withOpacity(.5),
                        ),
                      );
                    },
                    optionsViewBuilder: (BuildContext context,
                        AutocompleteOnSelected<CustomerListModelData>
                            onSelected,
                        Iterable<CustomerListModelData> options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: Container(
                            width: MediaQuery.of(context).size.width / 3,
                            color: Colors.white,
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8.0),
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final CustomerListModelData option =
                                    options.elementAt(index);
                                return MouseRegion(
                                  onEnter: (_) {
                                    setState(() {
                                      hoverMap[index] = true;
                                    });
                                  },
                                  onExit: (_) {
                                    setState(() {
                                      hoverMap[index] = false;
                                    });
                                  },
                                  child: GestureDetector(
                                    onTap: () {
                                      onSelected(option);
                                    },
                                    child: Container(
                                      color: hoverMap[index] == true
                                          ? Colors.grey[200]
                                          : Colors.white,
                                      child: ListTile(
                                        title: Text(
                                          "${option.name} ${option.phone}",
                                          style: buildCustomStyle(
                                            FontWeight.w500,
                                            12,
                                            0.27,
                                            Colors.black.withOpacity(.5),
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
        BuildBoxShadowContainer(
          height: size.height * .07,
          width: 50,
          circleRadius: 5,
          child: (widget.isCustomerFound || widget.selectedCustomerId != null)
              ? InkWell(
                  onTap: () => {},
                  child: const Icon(
                    Icons.check_circle,
                    color: ColorManager.kButtonGreen,
                    size: 30,
                  ),
                )
              : InkWell(
                  onTap: widget.onClearCustomerDetails,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Center(
                          child: WebsafeSvg.asset(
                            ImageAssets.oderlistCloseIcon,
                            width: 27,
                            color: ColorManager.kButtonRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// Helper function to avoid code duplication
Widget buildColumnWidgetForTextFields({
  required TextEditingController controller,
  required Size size,
  bool readOnly = false,
  String? hintText,
}) {
  return BuildBoxShadowContainer(
    circleRadius: 7,
    alignment: Alignment.centerLeft,
    margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
    padding: const EdgeInsets.only(left: 15),
    height: size.height * .07,
    width: size.width / 3,
    child: TextField(
      controller: controller,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hintText ?? 'Enter value',
        hintStyle: buildCustomStyle(
          FontWeight.w500,
          12,
          0.27,
          Colors.grey.withOpacity(.5),
        ),
        border: InputBorder.none,
      ),
      style: buildCustomStyle(
        FontWeight.w500,
        12,
        0.27,
        Colors.black.withOpacity(.5),
      ),
    ),
  );
} 