import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/whatsapp_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/print/print_standard.dart';
import 'package:pos_machine/screens/sales/widgets/buid_order_details_widget.dart';
import 'package:pos_machine/screens/sales/widgets/buid_order_return_details_widget.dart';
import 'package:pos_machine/screens/sales/widgets/change_order_status_modal.dart';
import 'package:pos_machine/screens/sales/widgets/change_payment_status_modal.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../components/build_container_box.dart';
import '../../../controllers/sidebar_controller.dart';
import '../../../providers/auth_model.dart';
import '../../../resources/app_url.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../responsive.dart';

class SalesOrderDetailsScreen extends StatefulWidget {
  const SalesOrderDetailsScreen({Key? key}) : super(key: key);

  @override
  State<SalesOrderDetailsScreen> createState() =>
      _SalesOrderDetailsScreenState();
}

class _SalesOrderDetailsScreenState extends State<SalesOrderDetailsScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());
  bool isInitLoading = false;
  String orderNumber = "";
  String? tokenNumber;
  OrderDetailsModelData? orderDetailsModelData;
  OrderDetailsModelDataCustomerDetails? customerDetails;
  OrderDetailsModelDataCart? cart;
  List<OrderDetailsModelDataCartItem>? cartItems = [];
  OrderDetailsModelDataPriceSummary? priceSummary;

  DocumentConfig? _resolvePdfBillDocumentConfig(
    DocumentConfigProvider docConfigProvider,
  ) {
    final hasReturns = orderDetailsModelData?.orderReturns != null &&
        orderDetailsModelData!.orderReturns!.returnItems != null &&
        orderDetailsModelData!.orderReturns!.returnItems!.isNotEmpty;

    if (hasReturns) {
      return docConfigProvider.getDocumentConfig("Sales and Return Bill A4") ??
          docConfigProvider.getDocumentConfig("Sales and Return Bill") ??
          docConfigProvider.getDocumentConfig("Bill A4") ??
          docConfigProvider.getDocumentConfig("Bill");
    }

    return docConfigProvider.getDocumentConfig("Bill A4") ??
        docConfigProvider.getDocumentConfig("Bill");
  }

  @override
  void initState() {
    super.initState();
    getOrderDetails();
  }

  Future<void> getOrderDetails() async {
    setState(() {
      isInitLoading = true;
    });

    try {
      String ordersId =
          Provider.of<SalesProvider>(context, listen: false).getOrderNumber;
      String? accessToken =
          Provider.of<AuthModel>(context, listen: false).token;

      final response = await SalesProvider()
          .listOrderDetails(context, ordersId, accessToken ?? "");

      if (response["status"] == "success") {
        setState(() {
          OrderDetailsModel? orderDetails;
          try {
            orderDetails = OrderDetailsModel.fromJson(response);
            if (orderDetails?.data != null) {
              orderDetailsModelData = orderDetails!.data;
              cart = orderDetailsModelData?.cart;
              priceSummary =
                  orderDetailsModelData?.priceSummary ?? cart?.priceSummary;
              customerDetails = orderDetailsModelData?.customerDetails;
              cartItems = cart?.cartItems ?? [];
              orderNumber = orderDetailsModelData?.orderNumber ?? "";
              tokenNumber = orderDetailsModelData?.tokenNumber;

              // Debug: Check payments data
              if (orderDetailsModelData?.payments != null) {
                debugPrint("Payments data: ${orderDetailsModelData?.payments}");
                orderDetailsModelData?.payments?.forEach((key, value) {
                  debugPrint("Payment method: $key, Amount: $value");
                });
              } else {
                debugPrint("No payments data found");
              }
            } else {
              orderNumber = 'sales_order_details.err_order_data_null'.tr;
            }
          } catch (e) {
            debugPrint("Error parsing JSON data: $e");
            orderNumber = 'sales_order_details.err_parsing_order_data'.tr;
          }
        });
      } else {
        setState(() {
          orderNumber = 'sales_order_details.err_order_not_found'.tr;
        });
      }
    } catch (error) {
      debugPrint("Error fetching order details: $error");
      setState(() {
        orderNumber = "Error fetching order details";
      });
    } finally {
      setState(() {
        isInitLoading = false;
      });
    }
  }

  /// Helper method to check if a phone number matches the default customer phone from app settings
  bool _isDefaultCustomerPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final appSettingsProvider =
        Provider.of<AppSettingsProvider>(context, listen: false);
    final defaultPhone =
        appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";
    return defaultPhone.isNotEmpty && phone == defaultPhone;
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final isMobile = ResponsiveWidget.isMobile(context);

    return SafeArea(
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.mouse,
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.trackpad,
            },
          ),
          child: SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.all(isMobile ? 4.0 : 10.0),
              padding: EdgeInsets.all(isMobile ? 4.0 : 8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isMobile ? 12 : 22),
                boxShadow: const [
                  BoxShadow(
                    color: ColorManager.boxShadowColor,
                    blurRadius: 6,
                    offset: Offset(1, 1),
                  ),
                ],
                color: Colors.white,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 12.0 : 20.0,
                  horizontal: isMobile ? 8.0 : 10.0,
                ),
                child: isInitLoading
                    ? SizedBox(
                        height: isMobile ? 240 : size.height,
                        child: const Center(
                            child: CircularProgressIndicator.adaptive()))
                    : Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // Align items to start
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 10),
                          SelectableText(
                            '${'sales_order_details.title'.tr} $orderNumber',
                            style: ResponsiveWidget.isMobile(context)
                                ? buildCustomStyle(FontWeightManager.semiBold,
                                    FontSize.s12, 0.30, ColorManager.textColor)
                                : buildCustomStyle(FontWeightManager.semiBold,
                                    FontSize.s20, 0.30, ColorManager.textColor),
                          ),
                          // Delivery Date/Time if present
                          if ((orderDetailsModelData?.orderProps != null) ||
                              orderDetailsModelData?.deliveryDate != null ||
                              orderDetailsModelData?.deliveryTime != null) ...[
                            Builder(
                              builder: (context) {
                                final dateProp = orderDetailsModelData
                                    ?.orderProps
                                    ?.firstWhere(
                                  (prop) =>
                                      prop.propsCode?.toUpperCase() ==
                                      'DELIVERY_DATE',
                                  orElse: () => OrderDetailsModelDataOrderProp(
                                      propsId: null,
                                      propsCode: null,
                                      propsValue: null),
                                );
                                final timeProp = orderDetailsModelData
                                    ?.orderProps
                                    ?.firstWhere(
                                  (prop) =>
                                      prop.propsCode?.toUpperCase() ==
                                      'DELIVERY_TIME',
                                  orElse: () => OrderDetailsModelDataOrderProp(
                                      propsId: null,
                                      propsCode: null,
                                      propsValue: null),
                                );
                                final effectiveDeliveryDate =
                                    dateProp?.propsValue?.isNotEmpty == true
                                        ? dateProp?.propsValue
                                        : orderDetailsModelData?.deliveryDate;
                                final effectiveDeliveryTime =
                                    timeProp?.propsValue?.isNotEmpty == true
                                        ? timeProp?.propsValue
                                        : orderDetailsModelData?.deliveryTime;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (effectiveDeliveryDate != null &&
                                        effectiveDeliveryDate.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          '${'sales_order_details.label_delivery_date'.tr}\t${DateHelper.formatISODate(effectiveDeliveryDate)}',
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              isMobile
                                                  ? FontSize.s12
                                                  : FontSize.s14,
                                              0.21,
                                              ColorManager.textColor),
                                        ),
                                      ),
                                    if (effectiveDeliveryTime != null &&
                                        effectiveDeliveryTime.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          '${'sales_order_details.label_delivery_time'.tr}\t$effectiveDeliveryTime',
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              isMobile
                                                  ? FontSize.s12
                                                  : FontSize.s14,
                                              0.21,
                                              ColorManager.textColor),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                          const SizedBox(height: 10),
                          BuildBoxShadowContainer(
                            circleRadius: 12,
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            offsetValue: const Offset(1, 1),
                            child: _buildActionButtons(),
                          ),
                          const SizedBox(height: 10),
                          _buildOrderDetails(),
                          const SizedBox(height: 10),
                          _buildOrderReturns(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        CustomBackButton(
          onPressed: () {
            final isOnline = Provider.of<SalesProvider>(context, listen: false)
                .isOnlineSalesNavigation;
            sideBarController.index.value = isOnline ? 92 : 2;
          },
          text: 'sales_order_details.btn_all_orders'.tr,
        ),
        BuildBoxShadowContainer(
          width: 15,
          height: 15,
          circleRadius: 10,
          color: ColorManager.kPrimaryColor,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              final isOnline =
                  Provider.of<SalesProvider>(context, listen: false)
                      .isOnlineSalesNavigation;
              sideBarController.index.value = isOnline ? 92 : 2;
            },
            icon:
                const Icon(Icons.close_rounded, size: 10, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetails() {
    if (orderDetailsModelData == null) {
      return Text('sales_order_details.msg_no_order_data'.tr);
    }
    return OrderDetailWidget(
      orderDetailsModelData: orderDetailsModelData,
      priceSummary: priceSummary,
      cartItem: cartItems,
      customerDetails: customerDetails,
    );
  }

  Widget _buildOrderReturns() {
    // Check if orderReturns is null or has no return items
    if (orderDetailsModelData?.orderReturns == null ||
        (orderDetailsModelData?.orderReturns?.returnItems?.isEmpty ?? true)) {
      return const SizedBox(); // Return an empty SizedBox to hide the widget
    }

    // If there are return items, show the OrderReturnsWidget
    return OrderReturnsWidget(
      orderReturns: orderDetailsModelData?.orderReturns,
      cartItems: cartItems,
      priceSummary: priceSummary,
    );
  }

  Widget _buildActionButtons() {
    final isMobile = ResponsiveWidget.isMobile(context);

    return LayoutBuilder(
        builder: (context, constraints) {
          final buttonWidth =
              isMobile ? (constraints.maxWidth - 10) / 2 : 168.0;
          final buttonHeight = isMobile ? 40.0 : 40.0;
          final buttonFontSize = isMobile ? FontSize.s11 : FontSize.s12;

          return Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.start,
            children: [
              CustomRoundButton(
                title: 'sales_order_details.btn_print'.tr,
            icon: const Icon(Icons.print_outlined,
                size: 16, color: ColorManager.kPrimaryColor),
            boxColor: Colors.white,
            borderColor: ColorManager.kPrimaryColor,
            textColor: ColorManager.kPrimaryColor,
            fct: () async {
              if (orderDetailsModelData?.cart == null ||
                  cartItems == null ||
                  cartItems!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('sales_order_details.msg_no_print_data'.tr),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              String? formattedTotal = orderDetailsModelData
                      ?.cart?.priceSummary?.netPayable
                      ?.toString() ??
                  orderDetailsModelData?.cart?.priceSummary?.netTotal
                      ?.toString() ??
                  "0.00";
              String? savedTotal = orderDetailsModelData
                      ?.cart?.priceSummary?.savedTotal
                      ?.toString() ??
                  "0.00";
              String? discountAmount = orderDetailsModelData
                      ?.cart?.priceSummary?.discount
                      ?.toString() ??
                  "0.00";
              String storeName =
                  orderDetailsModelData?.cart?.storeName ?? 'sales_order_details.label_store'.tr;
              String orderDate = orderDetailsModelData?.orderDate ?? "";

              String? customerName = customerDetails?.name;
              String? customerPhone = customerDetails?.phone;
              String? customerEmail = customerDetails?.email;
              String? customerAddress =
                  orderDetailsModelData?.getCustomerAddressForDisplay();
              String? customerAlternatePhone = customerDetails?.alternatePhone;
              String? customerType = customerDetails?.customerType;
              String? paymentMethod =
                  orderDetailsModelData?.paymentDetails?.paymentMethod;
              String? customerVatNumber =
                  orderDetailsModelData?.kycInfo?.vatNumber;
              String? customerCrNumber =
                  orderDetailsModelData?.kycInfo?.crNumber;
              String? deliveryMethod =
                  orderDetailsModelData?.deliveryMethodName;

              String? orderComment;
              if (orderDetailsModelData?.orderProps != null) {
                try {
                  final commentProp =
                      orderDetailsModelData!.orderProps!.firstWhere(
                    (prop) => prop.propsCode == "COMMENT",
                    orElse: () => OrderDetailsModelDataOrderProp(),
                  );
                  orderComment = commentProp.propsValue;
                } catch (e) {
                  debugPrint("Error extracting order comment: $e");
                }
              }

              // Calculate Paid Amount from payments map
              double paidAmount = 0.0;
              if (orderDetailsModelData?.payments != null) {
                orderDetailsModelData!.payments!.forEach((key, value) {
                  paidAmount += double.tryParse(value.toString()) ?? 0.0;
                });
              }

              // Calculate Balance from orderProps
              double? customerCurrentBalance;
              if (orderDetailsModelData?.orderProps != null) {
                try {
                  final balanceProp =
                      orderDetailsModelData!.orderProps!.firstWhere(
                    (prop) => prop.propsCode == "BALANCE",
                    orElse: () => OrderDetailsModelDataOrderProp(),
                  );
                  if (balanceProp.propsValue != null) {
                    customerCurrentBalance =
                        double.tryParse(balanceProp.propsValue.toString());
                  }
                } catch (e) {
                  debugPrint("Error extracting balance: $e");
                }
              }

              // Try auto-print with default printer first
              final _hasReturns = orderDetailsModelData?.orderReturns != null &&
                  (orderDetailsModelData
                          ?.orderReturns?.returnItems?.isNotEmpty ??
                      false);
              final autoPrintSuccess = await PrintPage.autoPrint(
                context,
                storeName: storeName,
                cartItems: cartItems ?? [],
                formattedTotal: formattedTotal,
                savedTotal: savedTotal,
                discountAmount: discountAmount,
                orderDate: orderDate,
                orderNumber: orderNumber,
                tokenNumber: tokenNumber,
                customerName: customerName,
                customerPhone: customerPhone,
                customerEmail: customerEmail,
                customerAddress: customerAddress,
                customerAlternatePhone: customerAlternatePhone,
                paymentMethod: paymentMethod,
                paymentBreakdown: orderDetailsModelData?.payments,
                customerVatNumber: customerVatNumber,
                customerCrNumber: customerCrNumber,
                customerType: customerType,
                orderComment: orderComment,
                deliveryMethod: deliveryMethod,
                orderReturns: orderDetailsModelData?.orderReturns,
                paidAmount: paidAmount > 0 ? paidAmount : null,
                customerCurrentBalance: customerCurrentBalance,
                isDefaultCustomer: _isDefaultCustomerPhone(customerPhone),
                netExcTax: orderDetailsModelData?.cart?.priceSummary?.netExcTax
                    ?.toString(),
                documentConfigType:
                    _hasReturns ? 'Sales and Return Bill' : 'Bill',
                apiTotalTax:
                    orderDetailsModelData?.priceSummary?.totalTax?.toDouble(),
              );

              // Only show print page if auto-print failed
              if (!autoPrintSuccess && mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PrintPage(
                      storeName: storeName,
                      cartItems: cartItems ?? [],
                      formattedTotal: formattedTotal,
                      savedTotal: savedTotal,
                      discountAmount: discountAmount,
                      orderDate: orderDate,
                      orderNumber: orderNumber,
                      tokenNumber: tokenNumber,
                      customerName: customerName,
                      customerPhone: customerPhone,
                      customerEmail: customerEmail,
                      customerAddress: customerAddress,
                      customerAlternatePhone: customerAlternatePhone,
                      paymentMethod: paymentMethod,
                      paymentBreakdown: orderDetailsModelData?.payments,
                      customerVatNumber: customerVatNumber,
                      customerCrNumber: customerCrNumber,
                      customerType: customerType,
                      orderComment: orderComment,
                      deliveryMethod: deliveryMethod,
                      orderReturns: orderDetailsModelData?.orderReturns,
                      paidAmount: paidAmount > 0 ? paidAmount : null,
                      customerCurrentBalance: customerCurrentBalance,
                      isDefaultCustomer: _isDefaultCustomerPhone(customerPhone),
                      netExcTax: orderDetailsModelData
                          ?.cart?.priceSummary?.netExcTax
                          ?.toString(),
                      documentConfigType:
                          _hasReturns ? 'Sales and Return Bill' : 'Bill',
                      apiTotalTax: orderDetailsModelData?.priceSummary?.totalTax
                          ?.toDouble(),
                    ),
                  ),
                );
              }
                },
                height: buttonHeight,
                width: buttonWidth,
                fontSize: buttonFontSize,
              ),
              CustomRoundButton(
                title: 'sales_order_details.btn_share'.tr,
            icon: const Icon(Icons.share_outlined, size: 16, color: Colors.blue),
            boxColor: Colors.white,
            borderColor: Colors.blue,
            textColor: Colors.blue,
            fct: () async {
              await _showShareOptions();
                },
                height: buttonHeight,
                width: buttonWidth,
                fontSize: buttonFontSize,
              ),
              CustomRoundButton(
                title: 'sales_order_details.btn_return'.tr,
            icon: const Icon(Icons.assignment_return_outlined,
                size: 16, color: Color(0xFFE53E3E)),
            boxColor: Colors.white,
            borderColor: const Color(0xFFE53E3E),
            textColor: const Color(0xFFE53E3E),
            fct: () async {
              final orderNo = orderDetailsModelData?.orderNumber;
              if (orderNo == null || orderNo.isEmpty) {
                showScaffoldError(
                  context: context,
                  message: 'sales_order_details.msg_no_order_number'.tr,
                );
                return;
              }

              try {
                Provider.of<SalesProvider>(context, listen: false)
                    .setOrderNumber(orderNo);

                final ordersId = orderDetailsModelData?.ordersId;
                if (ordersId != null) {
                  Provider.of<SalesProvider>(context, listen: false)
                      .setOrderId(ordersId.toString());
                }

                final cartId = cart?.id;
                if (cartId != null) {
                  Provider.of<CartProvider>(context, listen: false)
                      .setCartIDForOrder(cartId);
                }

                Get.find<SideBarController>().index.value = 49;

                if (context.mounted) {
                  showScaffold(
                    context: context,
                    message: '${'sales_order_details.msg_preparing_return'.tr} #$orderNo',
                  );
                }
              } catch (e) {
                debugPrint('Error preparing order return: $e');
                if (context.mounted) {
                  showScaffoldError(
                    context: context,
                    message: 'sales_order_details.msg_error_return'.tr,
                  );
                }
              }
                },
                height: buttonHeight,
                width: buttonWidth,
                fontSize: buttonFontSize,
              ),
              CustomRoundButton(
                title: 'sales_order_details.btn_order_status'.tr,
            icon: const Icon(Icons.local_shipping_outlined,
                size: 16, color: Color(0xFF6A1B9A)),
            boxColor: Colors.white,
            borderColor: const Color(0xFF6A1B9A),
            textColor: const Color(0xFF6A1B9A),
            fct: () {
              showDialog(
                context: context,
                builder: (dialogCtx) => ChangeOrderStatusModal(
                  currentStatus:
                      orderDetailsModelData?.orderStatus ?? 'pending',
                  orderTotal: priceSummary?.netPayable?.toString() ?? '0',
                  onConfirm: ({
                    required newStatus,
                    refundAmount,
                    paymentMethod,
                    deliveryChargeRefundable,
                    deliveryLogistics,
                  }) async {
                    try {
                      final authModel =
                          Provider.of<AuthModel>(context, listen: false);
                      final salesProvider =
                          Provider.of<SalesProvider>(context, listen: false);
                      await salesProvider.changeOrderStatus(
                        accessToken: authModel.token ?? '',
                        orderId:
                            orderDetailsModelData?.ordersId?.toString() ?? '',
                        status: newStatus,
                        refundAmount: refundAmount,
                        paymentMethod: paymentMethod,
                        deliveryChargeRefundable: deliveryChargeRefundable,
                        deliveryLogistics: deliveryLogistics,
                      );
                      if (context.mounted) {
                        showScaffold(
                          context: context,
                          message: '${'sales_order_details.msg_status_updated'.tr} $newStatus',
                        );
                        getOrderDetails();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showScaffoldError(
                          context: context,
                          message: '${'sales_order_details.msg_failed_status'.tr} $e',
                        );
                      }
                    }
                  },
                ),
              );
                },
                height: buttonHeight,
                width: buttonWidth,
                fontSize: buttonFontSize,
              ),
              CustomRoundButton(
                title: 'sales_order_details.btn_payment_status'.tr,
            icon: const Icon(Icons.payments_outlined,
                size: 16, color: Color(0xFF1E88E5)),
            boxColor: Colors.white,
            borderColor: const Color(0xFF1E88E5),
            textColor: const Color(0xFF1E88E5),
            fct: () {
              showDialog(
                context: context,
                builder: (dialogCtx) => ChangePaymentStatusModal(
                  currentPaymentStatus:
                      orderDetailsModelData?.paymentStatus ?? 'unpaid',
                  grandTotal: priceSummary?.netPayable?.toString() ?? '0',
                  onConfirm: (newStatus, amount) async {
                    try {
                      final authModel =
                          Provider.of<AuthModel>(context, listen: false);
                      final salesProvider =
                          Provider.of<SalesProvider>(context, listen: false);
                      await salesProvider.changePaymentStatus(
                        accessToken: authModel.token ?? '',
                        orderId:
                            orderDetailsModelData?.ordersId?.toString() ?? '',
                        status: newStatus,
                        amount: amount,
                      );
                      if (context.mounted) {
                        showScaffold(
                          context: context,
                          message: '${'sales_order_details.msg_payment_updated'.tr} $newStatus',
                        );
                        getOrderDetails();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showScaffoldError(
                          context: context,
                          message: '${'sales_order_details.msg_failed_payment'.tr} $e',
                        );
                      }
                    }
                  },
                ),
              );
                },
                height: buttonHeight,
                width: buttonWidth,
                fontSize: buttonFontSize,
              ),
            ],
          );
        },
    );
  }

  Future<void> _showShareOptions() async {
    if (orderDetailsModelData == null) {
      showScaffoldError(
        context: context,
        message: 'sales_order_details.msg_not_available'.tr,
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'sales_order_details.title_share_invoice'.tr,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1AE53E3E),
                    child: Icon(Icons.picture_as_pdf_outlined,
                        color: Color(0xFFE53E3E)),
                  ),
                  title: Text('sales_order_details.opt_share_pdf'.tr),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _sharePDFInvoice();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A1E88E5),
                    child: Icon(Icons.email, color: Color(0xFF1E88E5)),
                  ),
                  title: Text(
                    customerDetails?.email != null &&
                            customerDetails!.email!.isNotEmpty
                        ? '${'sales_order_details.opt_share_email'.tr} (${customerDetails!.email})'
                        : 'sales_order_details.opt_share_email'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareViaEmail();
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0x1A25D366),
                    child: Icon(Icons.message, color: Color(0xFF25D366)),
                  ),
                  title: Text(
                    customerDetails?.phone != null &&
                            customerDetails!.phone!.isNotEmpty
                        ? '${'sales_order_details.opt_share_whatsapp'.tr} (${customerDetails!.phone})'
                        : 'sales_order_details.opt_share_whatsapp'.tr,
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _shareViaWhatsApp();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sharePDFInvoice() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      if (orderDetailsModelData == null ||
          orderDetailsModelData!.cart?.cartItems == null) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'sales_order_details.msg_no_pdf_data'.tr,
          );
        }
        return;
      }

      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      final appSettings = appSettingsProvider.appSettings;

      final billDocumentConfig = _resolvePdfBillDocumentConfig(
        docConfigProvider,
      );

      if (appSettings == null || billDocumentConfig == null) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'sales_order_details.msg_no_app_settings'.tr,
          );
        }
        return;
      }

      String? customerAlternatePhone = customerDetails?.alternatePhone;
      String? paymentMethod =
          orderDetailsModelData?.paymentDetails?.paymentMethod;
      String? deliveryMethod = orderDetailsModelData?.deliveryMethodName;

      String? orderComment;
      if (orderDetailsModelData?.orderProps != null) {
        try {
          final commentProp = orderDetailsModelData!.orderProps!.firstWhere(
            (prop) => prop.propsCode == "COMMENT",
            orElse: () => OrderDetailsModelDataOrderProp(),
          );
          orderComment = commentProp.propsValue;
        } catch (e) {
          // ignore
        }
      }

      final standardPrinter = StandardPrinter(context);

      final storeSessionForShare =
          Provider.of<StoreSessionProvider>(context, listen: false);
      final File? pdfFile = await standardPrinter.generateThemedPDFForSharing(
        cartItems: orderDetailsModelData!.cart!.cartItems!,
        formattedTotal:
            orderDetailsModelData!.priceSummary?.netPayable?.toString() ??
                orderDetailsModelData!.priceSummary?.netTotal?.toString() ??
                '0.00',
        savedTotal:
            orderDetailsModelData!.priceSummary?.savedTotal?.toString() ??
                '0.00',
        discountAmount:
            orderDetailsModelData!.priceSummary?.discount?.toString() ?? '0.00',
        orderDate: orderDetailsModelData!.orderDate ??
            DateHelper.now().toIso8601String(),
        orderNumber: orderNumber,
        isFromLocalStorage: false,
        billDocumentConfig: billDocumentConfig,
        customerCareNumber: appSettings.customerCarePhone,
        customerCareEmail: appSettings.customerCareEmail,
        customerName: customerDetails?.name,
        customerPhone: customerDetails?.phone,
        customerEmail: customerDetails?.email,
        customerAddress: orderDetailsModelData?.getCustomerAddressForDisplay(),
        orderReturns: orderDetailsModelData!.orderReturns,
        customerAlternatePhone: customerAlternatePhone,
        paymentMethod: paymentMethod,
        orderComment: orderComment,
        deliveryMethod: deliveryMethod,
        customerVatNumber: orderDetailsModelData?.kycInfo?.vatNumber,
        customerCrNumber: orderDetailsModelData?.kycInfo?.crNumber,
        customerType: orderDetailsModelData?.customerDetails?.customerType,
        storeLocation: storeSessionForShare.activeStore?.location,
        storePhone: storeSessionForShare.activeStore?.phone,
        storeEmail: storeSessionForShare.activeStore?.email,
      );

      Navigator.of(context, rootNavigator: true).pop();

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'sales_order_details.msg_pdf_failed'.tr,
          );
        }
        return;
      }

      if (Platform.isWindows) {
        try {
          final enhancedXFile = XFile(
            pdfFile.path,
            name: 'Invoice_$orderNumber.pdf',
            mimeType: 'application/pdf',
            length: await pdfFile.length(),
          );

          final params = ShareParams(
            files: [enhancedXFile],
          );

          final result = await SharePlus.instance.share(params);

          if (result.status == ShareResultStatus.success) {
            debugPrint('Windows file sharing succeeded!');
          } else if (result.status == ShareResultStatus.dismissed) {
            if (context.mounted) {
              showScaffold(
                context: context,
                message: 'sales_order_details.msg_sharing_cancelled'.tr,
              );
            }
            return;
          } else {
            _handleWindowsAlternativeSharing(pdfFile);
            return;
          }
        } catch (e) {
          debugPrint('ShareParams API failed: $e');
          _handleWindowsAlternativeSharing(pdfFile);
          return;
        }
      } else {
        final enhancedXFile = XFile(
          pdfFile.path,
          name: 'Invoice_$orderNumber.pdf',
          mimeType: 'application/pdf',
        );

        final params = ShareParams(
          text: 'sales_order_details.msg_share_pdf_text'.trParams({'orderNumber': orderNumber}),
          files: [enhancedXFile],
        );

        await SharePlus.instance.share(params);
      }

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'sales_order_details.msg_pdf_shared'.tr,
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      debugPrint('Error sharing PDF invoice: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales_order_details.msg_pdf_share_error'.tr,
        );
      }
    }
  }

  Future<void> _handleWindowsAlternativeSharing(File pdfFile) async {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.picture_as_pdf, color: Colors.red),
              const SizedBox(width: 8),
              Text('sales_order_details.title_pdf_ready'.tr),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${'sales_order_details.label_invoice'.tr} $orderNumber'),
              const SizedBox(height: 8),
              Text('${'sales_order_details.label_file'.tr} ${pdfFile.path.split('/').last}'),
              const SizedBox(height: 16),
              Text(
                'sales_order_details.label_choose_share'.tr,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await Process.start(
                    'explorer.exe',
                    ['/select,', pdfFile.path.replaceAll('/', '\\')],
                    mode: ProcessStartMode.detached,
                  );
                  if (context.mounted) {
                    showScaffold(
                      context: context,
                      message: 'sales_order_details.msg_file_location_opened'.tr,
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening file location: $e');
                }
              },
              icon: const Icon(Icons.folder_open),
              label: Text('sales_order_details.btn_open_file_location'.tr),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await Process.start(
                    'cmd',
                    ['/c', 'start', '""', pdfFile.path],
                    mode: ProcessStartMode.detached,
                  );
                  if (context.mounted) {
                    showScaffold(
                      context: context,
                      message: 'sales_order_details.msg_pdf_opened'.tr,
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening PDF: $e');
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: Text('sales_order_details.btn_open_pdf'.tr),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await Clipboard.setData(ClipboardData(text: pdfFile.path));
                  if (context.mounted) {
                    showScaffold(
                      context: context,
                      message: 'sales_order_details.msg_path_copied'.tr,
                    );
                  }
                } catch (e) {
                  debugPrint('Error copying to clipboard: $e');
                }
              },
              icon: const Icon(Icons.copy),
              label: Text('sales_order_details.btn_copy_path'.tr),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _shareViaEmail() async {
    final invoiceUrl = orderDetailsModelData?.orderNumber != null
        ? '${APPUrl.baseURL}/invoice/${orderDetailsModelData!.orderNumber}'
        : null;

    if (invoiceUrl == null) {
      showScaffoldError(
        context: context,
        message: 'sales_order_details.msg_no_invoice_url'.tr,
      );
      return;
    }

    final message = 'sales_order_details.msg_email_body'.trParams({'invoiceUrl': invoiceUrl});
    final uri = Uri(
      scheme: 'mailto',
      path: customerDetails?.email ?? '',
      queryParameters: <String, String>{
        'subject': 'sales_order_details.msg_email_subject'.trParams({'orderNumber': orderNumber}),
        'body': message,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales_order_details.msg_no_email_app'.tr,
        );
      }
    }
  }

  Future<void> _shareViaWhatsApp() async {
    try {
      final whatsappProvider =
          Provider.of<WhatsappProvider>(context, listen: false);

      if (!whatsappProvider.isWhatsAppAvailable()) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text('sales_order_details.title_wa_not_connected'.tr),
              ],
            ),
            content: Text(
              '${'sales_order_details.msg_wa_not_connected'.tr}\n\n'
              '${'sales_order_details.label_wa_status'.tr} ${whatsappProvider.connectionStatus}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('general.cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  Get.find<SideBarController>().index.value = 63;
                },
                child: Text('sales_order_details.btn_connect_whatsapp'.tr),
              ),
            ],
          ),
        );
        return;
      }

      if (customerDetails?.phone == null || customerDetails!.phone!.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'sales_order_details.msg_no_phone'.tr,
        );
        return;
      }

      final customerPhone = customerDetails!.phone!;
      final customerName = customerDetails?.name ?? 'sales_order_details.label_default_customer'.tr;
      final totalAmount =
          orderDetailsModelData?.priceSummary?.netPayable?.toString() ??
              orderDetailsModelData?.priceSummary?.netTotal?.toString() ??
              '0.00';
      final currency = Provider.of<AppSettingsProvider>(context, listen: false)
              .appSettings
              ?.currency ??
          'INR';

      final success = await whatsappProvider.sendInvoiceMessage(
        phoneNumber: customerPhone,
        orderNumber: orderNumber,
        customerName: customerName,
        totalAmount: '$currency $totalAmount',
        invoiceUrl: '${APPUrl.baseURL}/invoice/$orderNumber',
      );

      if (context.mounted) {
        if (success) {
          showScaffold(
            context: context,
            message: '${'sales_order_details.msg_invoice_sent_wa'.tr} $customerPhone',
          );
        } else {
          showScaffoldError(
            context: context,
            message:
                '${'sales_order_details.msg_wa_send_failed'.tr} ${whatsappProvider.lastError}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error in WhatsApp sharing: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'sales_order_details.msg_wa_error'.tr,
        );
      }
    }
  }
}
