// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_payment_row.dart';
import 'package:pos_machine/components/build_tax_modal.dart';
import 'package:pos_machine/components/build_title.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/add_to_order.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/list_cart.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/location_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/kiosk/kiosk.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_action_guard.dart';

import '../../extensions/widget_functions.dart';

class KioskBillingPage extends StatefulWidget {
  const KioskBillingPage({Key? key}) : super(key: key);

  @override
  KioskBillingPageState createState() => KioskBillingPageState();
}

class KioskBillingPageState extends State<KioskBillingPage> {
  final TextEditingController _transactionNumberController =
      TextEditingController();

  final firstNameTextController = TextEditingController();
  final lastNameTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final addressTextController = TextEditingController();
  final countryTextController = TextEditingController();
  final pincodeTextController = TextEditingController();

  String? selectedStateId;
  String? selectedDistrictId;

  String mobileNumberText = "";
  CartProvider cartProvider = CartProvider();
  int iconColor = 0;
  UniqueKey keyTile = UniqueKey();
  bool isInitLoading = false;
  List<CustomerListModelData>? customerList = [];
  CustomerListModelData? selectedCustomer;
  List<ListCartModelDataCartItem>? cartProductItems = [];
  Map<String, int> taxNames = {};
  Map<int, bool> hoverMap = {};

  @override
  void initState() {
    super.initState();
    _fetchCartData();
    getCustomersDetails();
  }

  void _fetchCartData() {
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    int? customerId = Provider.of<AuthModel>(context, listen: false).userId;

    // debugPrint("accessToken From AuthModel $accessToken");
    Provider.of<CartProvider>(context, listen: false).fetchCartDataFromApi(
        customerId: customerId ?? 1, accessToken: accessToken ?? '');
  }

  Future<void> getCustomersDetails() async {
    try {
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;
      // debugPrint("accessToken From AuthModel $accessToken");

      final response =
          await CustomerProvider().listCustomer(accessToken: accessToken ?? "");

      if (response["status"] == "success") {
        CustomerListModel customerListModel =
            CustomerListModel.fromJson(response);
        setState(() {
          customerList = customerListModel.data;
        });
      } else {
        // Handle error
      }
    } catch (error) {
      // debugPrint(error.toString());
    }
  }

  @override
  void dispose() {
    _transactionNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'kiosk_billing.page_title'.tr,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: FontSize.s16),
        ),
      ),
      body: _buildBody(size),
    );
  }

  Widget _buildBody(Size size) {
    return BuildBoxShadowContainer(
      circleRadius: 13,
      color: Colors.white,
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildPaymentMethod(),
                    _buildCustomerDetails(size),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            _buildPaymentSummary(),
            const SizedBox(height: 10),
            _buildConfirmationButtons(size),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDetails(Size size) {
    final locationProvider = Provider.of<LocationProvider>(context);
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;

    // Fetch states when the modal is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      locationProvider.listAllStates(accessToken!);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildTextTile(
          title: 'kiosk_billing.label_first_name'.tr,
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        Row(
          children: [
            BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.only(left: 15),
              height: size.height * .07,
              width: size.width / 3.05,
              child: TextFormField(
                keyboardType: TextInputType.text,
                cursorColor: ColorManager.kPrimaryColor,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                controller: firstNameTextController,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
              ),
            ),
            BuildBoxShadowContainer(
              circleRadius: 7,
              alignment: Alignment.centerLeft,
              margin: const EdgeInsets.only(left: 20),
              padding: const EdgeInsets.only(left: 15),
              height: size.height * .07,
              width: size.width / 3.05,
              child: TextFormField(
                keyboardType: TextInputType.text,
                cursorColor: ColorManager.kPrimaryColor,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                controller: lastNameTextController,
                style: buildCustomStyle(
                  FontWeightManager.medium,
                  FontSize.s12,
                  0.27,
                  ColorManager.textColor.withOpacity(.5),
                ),
              ),
            ),
          ],
        ),
        BuildTextTile(
          title: 'kiosk_billing.label_email'.tr,
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.only(left: 20, right: 10),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
          width: size.width,
          child: TextFormField(
            keyboardType: TextInputType.text,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: validateEmail,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            controller: emailTextController,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
        BuildTextTile(
          title: 'kiosk_billing.label_phone'.tr,
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s14,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.only(left: 20, right: 10),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
          width: size.width,
          child: TextFormField(
            keyboardType: TextInputType.number,
            inputFormatters: [PhoneNumberFormatter()],
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            controller: phoneNumberController,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
        BuildTextTile(
          title: 'kiosk_billing.label_address'.tr,
          textStyle: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s12,
            0.27,
            Colors.black.withOpacity(0.6),
          ),
        ),
        BuildBoxShadowContainer(
          circleRadius: 7,
          alignment: Alignment.centerLeft,
          margin: const EdgeInsets.only(left: 20, right: 10),
          padding: const EdgeInsets.only(left: 15),
          height: size.height * .07,
          width: size.width,
          child: TextFormField(
            keyboardType: TextInputType.text,
            cursorColor: ColorManager.kPrimaryColor,
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            controller: addressTextController,
            style: buildCustomStyle(
              FontWeightManager.medium,
              FontSize.s12,
              0.27,
              ColorManager.textColor.withOpacity(.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary() {
    return Column(
      children: [
        BuildPaymentRow(
          amount: AmountHelper.formatAmount(
              Provider.of<CartProvider>(context, listen: true)
                      .priceSummary!
                      .subTotal ??
                  0.00),
          title: 'kiosk_billing.net_amount'.tr,
          color: ColorManager.textColor,
        ),
        BuildPaymentRow(
          amount: "0.00",
          title: 'kiosk_billing.shipping'.tr,
          color: ColorManager.textColor,
        ),
        BuildPaymentRow(
          amount: AmountHelper.formatAmount(
              Provider.of<CartProvider>(context, listen: true)
                      .priceSummary!
                      .discount ??
                  0.00),
          title: 'kiosk_billing.discount'.tr,
          color: ColorManager.textColor,
        ),
        GestureDetector(
          child: BuildPaymentRow(
            amount: AmountHelper.formatAmount(
                Provider.of<CartProvider>(context, listen: true)
                        .priceSummary!
                        .totalTax ??
                    0.00),
            title: 'kiosk_billing.gst'.tr,
            color: ColorManager.kPrimaryColor,
          ),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return Center(
                  child: TaxDetailsDialog(
                    taxAmounts: Provider.of<CartProvider>(context, listen: true)
                            .cartData
                            .first
                            .taxAmounts ??
                        {},
                  ),
                );
              },
            );
          },
        ),
        const Divider(thickness: 2),
        BuildPaymentRow(
          amount: AmountHelper.formatAmount(
              Provider.of<CartProvider>(context, listen: true)
                      .priceSummary!
                      .netTotal ??
                  0.00),
          title: 'kiosk_billing.total_payable'.tr,
          secondRowTextStyle: buildCustomStyle(FontWeightManager.bold,
              FontSize.s15, 0.23, ColorManager.textColor),
          firstRowTextStyle: buildCustomStyle(FontWeightManager.bold,
              FontSize.s15, 0.23, ColorManager.textColor),
          color: ColorManager.textColor,
        ),
      ],
    );
  }

  Widget _buildPaymentMethod() {
    return Padding(
      padding: const EdgeInsets.only(left: 15),
      child: Column(
        children: [
          const SizedBox(height: 5),
          BuildPaymentRow(
            amount: "",
            title: 'kiosk_billing.chose_payment_method'.tr,
            firstRowTextStyle: buildCustomStyle(FontWeightManager.semiBold,
                FontSize.s14, 0.21, ColorManager.kPrimaryColor),
            color: ColorManager.kPrimaryColor,
          ),
          _buildPaymentMethodSelection(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelection() {
    return Row(
      children: [
        _buildPaymentMethodOption(Icons.monetization_on, 'kiosk_billing.payment_cash'.tr, 1),
        _buildPaymentMethodOption(Icons.credit_card, 'kiosk_billing.payment_card'.tr, 2),
        _buildPaymentMethodOption(Icons.mobile_friendly, 'kiosk_billing.payment_upi'.tr, 3),
      ],
    );
  }

  Widget _buildPaymentMethodOption(
      IconData icon, String label, int colorIndex) {
    return GestureDetector(
      onTap: () {
        setState(() {
          iconColor = colorIndex;
        });
      },
      child: BuildBoxShadowContainer(
        border: iconColor == colorIndex
            ? Border.all(color: ColorManager.kPrimaryColor)
            : null,
        margin: const EdgeInsets.only(top: 10, right: 10),
        padding: const EdgeInsets.all(8),
        blurRadius: 4,
        circleRadius: 5,
        child: Column(
          children: [
            Icon(icon, color: Colors.black),
            Text(
              label,
              style: buildCustomStyle(
                  FontWeightManager.medium, FontSize.s8, 0.12, Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmationButtons(Size size) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13.0),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: ColorManager.greyWithOpacity60,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSaveSalesButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveSalesButton() {
    return Expanded(
      flex: 3,
      child: GestureDetector(
        onTap: _saveSales,
        child: Container(
            padding: const EdgeInsets.all(13),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(13.0)),
              color: ColorManager.kPrimaryColor,
            ),
            child: Center(
              child: Text(
                'kiosk_billing.btn_pay'.trParams({'amount': 'INR ${AmountHelper.formatAmount(Provider.of<CartProvider>(context, listen: true).priceSummary!.netTotal)}'}),
                style: buildCustomStyle(
                    FontWeightManager.medium, FontSize.s16, 0.27, Colors.white),
              ),
            )),
      ),
    );
  }

  Future<void> _saveSales() async {
    if (!await SubscriptionActionGuard.ensureOrderSubmissionAllowed(context)) {
      return;
    }
    String? accessToken = Provider.of<AuthModel>(context, listen: false).token;
    final provider = Provider.of<CartProvider>(context, listen: false);
    int? cartId = provider.getCartIDForOrder;

    try {
      await provider
          .addToOrderAPI(
        cartIds: cartId!,
        accessToken: accessToken ?? "",
        transactionId: _transactionNumberController.text,
        totalPrice: provider.priceSummary!.netTotal.toString(),
        customerId: Provider.of<AuthModel>(context, listen: false).userId!,
      )
          .then((response) async {
        if (await SubscriptionActionGuard.handleBackendResponse(
          context,
          response,
        )) {
          return;
        }
        AddToOrderModel addToOrderModel = AddToOrderModel.fromJson(response);
        if (response["status"] == "success") {
          showScaffold(context: context, message: "${addToOrderModel.message}");
          Provider.of<CartProvider>(context, listen: false)
              .resetProductCounts();
          Get.off(() => const KioskScreen());
        } else {
          showScaffoldError(
              context: context, message: "${addToOrderModel.message}");
        }
      });
    } catch (error) {
      // debugPrint(error.toString());
    }
  }
}
