import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/whatsapp_provider.dart';
import 'package:pos_machine/screens/print/print.dart';
import 'package:pos_machine/screens/print/print_standard.dart';
import 'package:pos_machine/screens/sales/widgets/buid_order_details_widget.dart';
import 'package:pos_machine/screens/sales/widgets/buid_order_return_details_widget.dart';
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
  OrderDetailsModelData? orderDetailsModelData;
  OrderDetailsModelDataCustomerDetails? customerDetails;
  OrderDetailsModelDataCart? cart;
  List<OrderDetailsModelDataCartItem>? cartItems = [];
  OrderDetailsModelDataPriceSummary? priceSummary;

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
              priceSummary = cart?.priceSummary;
              customerDetails = orderDetailsModelData?.customerDetails;
              cartItems = cart?.cartItems ?? [];
              orderNumber = orderDetailsModelData?.orderNumber ?? "N/A";

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
              orderNumber = "Order data is null";
            }
          } catch (e) {
            debugPrint("Error parsing JSON data: $e");
            orderNumber = "Error parsing order data";
          }
        });
      } else {
        setState(() {
          orderNumber = "Order Details Not found";
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
              margin: const EdgeInsets.all(10.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
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
                padding: const EdgeInsets.symmetric(
                    vertical: 20.0, horizontal: 10.0),
                child: isInitLoading
                    ? SizedBox(
                        height: size.height,
                        child: const Center(
                            child: CircularProgressIndicator.adaptive()))
                    : Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start, // Align items to start
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 10),
                          Text(
                            'Order Details - # $orderNumber',
                            style: ResponsiveWidget.isMobile(context)
                                ? buildCustomStyle(FontWeightManager.semiBold,
                                    FontSize.s12, 0.30, ColorManager.textColor)
                                : buildCustomStyle(FontWeightManager.semiBold,
                                    FontSize.s20, 0.30, ColorManager.textColor),
                            overflow: TextOverflow.ellipsis, // Handle overflow
                          ),
                          // Delivery Date/Time if present
                          if (orderDetailsModelData?.orderProps != null) ...[
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
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (dateProp?.propsCode != null &&
                                        dateProp?.propsValue != null &&
                                        (dateProp?.propsValue?.isNotEmpty ??
                                            false))
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 4.0),
                                        child: Text(
                                          'Delivery Date: 	${DateHelper.formatISODate(dateProp?.propsValue ?? '')}',
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s14,
                                              0.21,
                                              ColorManager.textColor),
                                        ),
                                      ),
                                    if (timeProp?.propsCode != null &&
                                        timeProp?.propsValue != null &&
                                        (timeProp?.propsValue?.isNotEmpty ??
                                            false))
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2.0),
                                        child: Text(
                                          'Delivery Time: 	${timeProp?.propsValue ?? ''}',
                                          style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s14,
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
                          _buildOrderDetails(),
                          const SizedBox(height: 10),
                          _buildOrderReturns(),
                          const SizedBox(height: 10),
                          _buildActionButtons(size),
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
            sideBarController.index.value = 2;
          },
          text: 'All Orders',
        ),
        BuildBoxShadowContainer(
          width: 15,
          height: 15,
          circleRadius: 10,
          color: ColorManager.kPrimaryColor,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () {
              sideBarController.index.value = 2;
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
      return const Text("No order details available.");
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

  Widget _buildActionButtons(Size size) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          CustomRoundButton(
            title: "Print",
            boxColor: Colors.white,
            textColor: ColorManager.kPrimaryColor,
            fct: () async {
              if (orderDetailsModelData?.cart == null ||
                  cartItems == null ||
                  cartItems!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No order data available for printing'),
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
                  orderDetailsModelData?.cart?.storeName ?? "Store";
              String orderDate = orderDetailsModelData?.orderDate ?? "";

              String? customerName = customerDetails?.name;
              String? customerPhone = customerDetails?.phone;
              String? customerEmail = customerDetails?.email;
              String? customerAddress =
                  orderDetailsModelData?.getCustomerAddressFromProps() ??
                      customerDetails?.address?.join(', ');
              String? customerAlternatePhone = customerDetails?.alternatePhone;
              String? paymentMethod =
                  orderDetailsModelData?.paymentDetails?.paymentMethod;

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

              // Note: Balance info not available from order details API
              // customerOldBalance, customerCurrentBalance, paidAmount will be null

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
                    customerName: customerName,
                    customerPhone: customerPhone,
                    customerEmail: customerEmail,
                    customerAddress: customerAddress,
                    customerAlternatePhone: customerAlternatePhone,
                    paymentMethod: paymentMethod,
                    orderComment: orderComment,
                    orderReturns: orderDetailsModelData?.orderReturns,
                    // Balance info not available from order details API
                    isDefaultCustomer: _isDefaultCustomerPhone(customerPhone),
                  ),
                ),
              );
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
          CustomRoundButton(
            title: "Share",
            boxColor: Colors.white,
            textColor: Colors.blue,
            fct: () async {
              await _showShareOptions();
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
          CustomRoundButton(
            title: "Return",
            boxColor: Colors.white,
            textColor: const Color(0xFFE53E3E),
            fct: () async {
              final orderNo = orderDetailsModelData?.orderNumber;
              if (orderNo == null || orderNo.isEmpty) {
                showScaffoldError(
                  context: context,
                  message: 'Order number not available for return.',
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
                    message: 'Preparing return for order #$orderNo',
                  );
                }
              } catch (e) {
                debugPrint('Error preparing order return: $e');
                if (context.mounted) {
                  showScaffoldError(
                    context: context,
                    message: 'Error preparing order return. Please try again.',
                  );
                }
              }
            },
            height: 50,
            width: size.width * 0.19,
            fontSize: FontSize.s12,
          ),
        ],
      ),
    );
  }

  Future<void> _showShareOptions() async {
    if (orderDetailsModelData == null) {
      showScaffoldError(
        context: context,
        message: 'Order details not available.',
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
                const Text(
                  'Share Invoice',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  title: const Text('Share as PDF'),
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
                        ? 'Share to Email (${customerDetails!.email})'
                        : 'Share to Email',
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
                        ? 'Share via WhatsApp (${customerDetails!.phone})'
                        : 'Share via WhatsApp',
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
            message: 'Order details not available for PDF generation.',
          );
        }
        return;
      }

      final appSettingsProvider =
          Provider.of<AppSettingsProvider>(context, listen: false);
      final docConfigProvider =
          Provider.of<DocumentConfigProvider>(context, listen: false);

      final appSettings = appSettingsProvider.appSettings;

      final billDocumentConfig = (orderDetailsModelData!.orderReturns != null &&
              orderDetailsModelData!.orderReturns!.returnItems != null &&
              orderDetailsModelData!.orderReturns!.returnItems!.isNotEmpty)
          ? (docConfigProvider.getDocumentConfig("Sales and Return Bill") ??
              docConfigProvider.getDocumentConfig("Bill"))
          : docConfigProvider.getDocumentConfig("Bill");

      if (appSettings == null || billDocumentConfig == null) {
        Navigator.of(context, rootNavigator: true).pop();
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'App settings or document configuration not loaded.',
          );
        }
        return;
      }

      String? customerAlternatePhone = customerDetails?.alternatePhone;
      String? paymentMethod =
          orderDetailsModelData?.paymentDetails?.paymentMethod;

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

      final File? pdfFile = await standardPrinter.generatePDFForSharing(
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
            DateTime.now().toIso8601String(),
        orderNumber: orderNumber,
        isFromLocalStorage: false,
        selectedPaperSize: 'A4',
        billDocumentConfig: billDocumentConfig,
        customerCareNumber: appSettings.customerCarePhone,
        customerCareEmail: appSettings.customerCareEmail,
        customerName: customerDetails?.name,
        customerPhone: customerDetails?.phone,
        customerEmail: customerDetails?.email,
        customerAddress: orderDetailsModelData?.getCustomerAddressFromProps() ??
            (customerDetails?.address?.isNotEmpty == true
                ? customerDetails!.address!.join(', ')
                : null),
        orderReturns: orderDetailsModelData!.orderReturns,
        customerAlternatePhone: customerAlternatePhone,
        paymentMethod: paymentMethod,
        orderComment: orderComment,
      );

      Navigator.of(context, rootNavigator: true).pop();

      if (pdfFile == null) {
        if (context.mounted) {
          showScaffoldError(
            context: context,
            message: 'Failed to generate PDF invoice.',
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
                message: 'Sharing cancelled by user.',
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
          text: 'Please find attached the invoice for order #$orderNumber',
          files: [enhancedXFile],
        );

        await SharePlus.instance.share(params);
      }

      if (context.mounted) {
        showScaffold(
          context: context,
          message: 'PDF invoice shared successfully!',
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
          message: 'Error generating or sharing PDF invoice. Please try again.',
        );
      }
    }
  }

  Future<void> _handleWindowsAlternativeSharing(File pdfFile) async {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red),
              SizedBox(width: 8),
              Text('PDF Invoice Ready'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invoice: $orderNumber'),
              const SizedBox(height: 8),
              Text('File: ${pdfFile.path.split('/').last}'),
              const SizedBox(height: 16),
              const Text(
                'Choose how to share your PDF:',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                      message:
                          'File location opened. The PDF is saved in Documents/epos folder.',
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening file location: $e');
                }
              },
              icon: const Icon(Icons.folder_open),
              label: const Text('Open File Location'),
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
                      message:
                          'PDF opened. You can now share it from your PDF viewer.',
                    );
                  }
                } catch (e) {
                  debugPrint('Error opening PDF: $e');
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open PDF'),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await Clipboard.setData(ClipboardData(text: pdfFile.path));
                  if (context.mounted) {
                    showScaffold(
                      context: context,
                      message: 'File path copied to clipboard!',
                    );
                  }
                } catch (e) {
                  debugPrint('Error copying to clipboard: $e');
                }
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy Path'),
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
        message: 'Invoice URL not available.',
      );
      return;
    }

    final message = 'Here is the link for your invoice: $invoiceUrl';
    final uri = Uri(
      scheme: 'mailto',
      path: customerDetails?.email ?? '',
      queryParameters: <String, String>{
        'subject': 'Invoice #$orderNumber',
        'body': message,
      },
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'No email app found to share the invoice.',
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
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('WhatsApp Not Connected'),
              ],
            ),
            content: Text(
              'WhatsApp bot is not connected. Would you like to connect now?\n\n'
              'Status: ${whatsappProvider.connectionStatus}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  Get.find<SideBarController>().index.value = 63;
                },
                child: const Text('Connect WhatsApp'),
              ),
            ],
          ),
        );
        return;
      }

      if (customerDetails?.phone == null || customerDetails!.phone!.isEmpty) {
        showScaffoldError(
          context: context,
          message: 'Customer phone number not available.',
        );
        return;
      }

      final customerPhone = customerDetails!.phone!;
      final customerName = customerDetails?.name ?? 'Valued Customer';
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
            message: 'Invoice sent via WhatsApp to $customerPhone',
          );
        } else {
          showScaffoldError(
            context: context,
            message:
                'Failed to send WhatsApp message: ${whatsappProvider.lastError}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error in WhatsApp sharing: $e');
      if (context.mounted) {
        showScaffoldError(
          context: context,
          message: 'Error sending WhatsApp message. Please try again.',
        );
      }
    }
  }
}
