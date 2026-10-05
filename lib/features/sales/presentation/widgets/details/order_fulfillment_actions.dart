import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fulfillment/external_delivery_dialog.dart';
import 'fulfillment/fulfillment_form_values.dart';
import 'fulfillment/packing_dialog.dart';

enum OrderFulfillmentAction { externalDelivery, packing }

/// The backend grants the two fulfilment actions to Sales Executive and
/// Restaurant Sales users. This small gate keeps the controls out of the
/// order view for all other roles; the API remains the final authorization
/// authority.
class OrderFulfillmentActionButton extends StatefulWidget {
  final OrderFulfillmentAction action;
  final String orderNumber;
  final String? orderStatus;
  final OrderDetailsModelDataPacking? packing;
  final Future<void> Function()? onSaved;

  const OrderFulfillmentActionButton({
    super.key,
    required this.action,
    required this.orderNumber,
    this.orderStatus,
    this.packing,
    this.onSaved,
  });

  @override
  State<OrderFulfillmentActionButton> createState() =>
      _OrderFulfillmentActionButtonState();
}

class _OrderFulfillmentActionButtonState
    extends State<OrderFulfillmentActionButton> {
  AuthModel? _auth;
  void _captureAuth() {
    try {
      _auth = context.read<AuthModel>();
    } on ProviderNotFoundException {
      _auth = null;
    }
  }

  bool? _canManage;

  @override
  void initState() {
    super.initState();
    _captureAuth();
    _loadPermission();
  }

  Future<void> _loadPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('userRole') ?? prefs.getString('user_role'))
        ?.trim()
        .toLowerCase();
    if (!mounted) return;
    setState(() {
      _canManage = role == 'sales_executive' || role == 'restaurant_sales';
    });
  }

  Future<void> _open() async {
    final token = _auth?.token;
    if (token == null || token.isEmpty) {
      showFulfillmentMessage(
          context, 'sales_order_details.msg_session_expired'.tr,
          isError: true);
      return;
    }

    if (widget.action == OrderFulfillmentAction.packing &&
        !_isPackableStatus(widget.orderStatus)) {
      showFulfillmentMessage(
          context, 'sales_order_details.msg_packing_order_status'.tr,
          isError: true);
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          widget.action == OrderFulfillmentAction.externalDelivery
              ? ExternalDeliveryDialog(
                  orderNumber: widget.orderNumber,
                  accessToken: token,
                )
              : PackingDialog(
                  orderNumber: widget.orderNumber,
                  accessToken: token,
                  packing: widget.packing,
                ),
    );
    if (saved == true && mounted) {
      showFulfillmentMessage(
        context,
        widget.action == OrderFulfillmentAction.externalDelivery
            ? 'sales_order_details.msg_delivery_created'.tr
            : 'sales_order_details.msg_packing_saved'.tr,
      );
      await widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_canManage != true || widget.orderNumber.isEmpty) {
      return const SizedBox.shrink();
    }
    final isPacking = widget.action == OrderFulfillmentAction.packing;
    final label = isPacking
        ? 'sales_order_details.btn_packing'.tr
        : 'sales_order_details.btn_create_delivery'.tr;
    return CustomRoundButton(
      title: label,
      fct: _open,
      height: 36,
      width: isPacking ? 120 : 170,
      fontSize: FontSize.s11,
      boxColor: Colors.white,
      borderColor: ColorManager.kPrimaryColor,
      textColor: ColorManager.kPrimaryColor,
      radius: 18,
      icon: Icon(
        isPacking ? Icons.inventory_2_outlined : Icons.local_shipping_outlined,
        size: 17,
        color: ColorManager.kPrimaryColor,
      ),
    );
  }
}

bool _isPackableStatus(String? status) {
  if (status == null || status.trim().isEmpty) return true;
  const permitted = {'confirmed', 'processing', 'shipped'};
  return permitted.contains(status.trim().toLowerCase());
}
