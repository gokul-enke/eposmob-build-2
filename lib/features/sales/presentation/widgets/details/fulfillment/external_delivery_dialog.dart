import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/order_fulfillment.dart';
import 'package:pos_machine/providers/order_fulfillment_provider.dart';

import 'fulfillment_dialog_frame.dart';
import 'fulfillment_fields.dart';
import 'fulfillment_form_values.dart';

class ExternalDeliveryDialog extends StatefulWidget {
  final String orderNumber;
  final String accessToken;

  const ExternalDeliveryDialog({
    required this.orderNumber,
    required this.accessToken,
  });

  @override
  State<ExternalDeliveryDialog> createState() => _ExternalDeliveryDialogState();
}

class _ExternalDeliveryDialogState extends State<ExternalDeliveryDialog> {
  final _api = OrderFulfillmentProvider();
  final _formKey = GlobalKey<FormState>();
  final _codAmount = TextEditingController();
  final _packageCount = TextEditingController();
  final _weight = TextEditingController();
  final _length = TextEditingController();
  final _breadth = TextEditingController();
  final _height = TextEditingController();
  final _shippingCharge = TextEditingController();
  final _trackingUrl = TextEditingController();
  final _shipmentId = TextEditingController();
  final _remarks = TextEditingController();
  final _dispatchDate = TextEditingController();
  final _expectedDelivery = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  List<ExternalLogistic> _logistics = const [];
  List<MasterDataValue> _shippingMethods = const [];
  List<MasterDataValue> _transportModes = const [];
  List<MasterDataValue> _paymentModes = const [];
  List<ExternalLogisticWarehouse> _warehouses = const [];
  ExternalLogistic? _selectedLogistic;
  ExternalLogisticWarehouse? _selectedWarehouse;
  bool _loadingWarehouses = false;
  int _warehouseRequestId = 0;
  String? _shippingService;
  String? _transportMode;
  String? _paymentMode;

  bool get _isCodPaymentMode => _paymentMode?.trim().toLowerCase() == 'cod';

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    for (final controller in [
      _codAmount,
      _packageCount,
      _weight,
      _length,
      _breadth,
      _height,
      _shippingCharge,
      _trackingUrl,
      _shipmentId,
      _remarks,
      _dispatchDate,
      _expectedDelivery,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        _api.fetchExternalLogistics(accessToken: widget.accessToken),
        _api.fetchMasterDataValues(
            accessToken: widget.accessToken, code: 'SHIPPING_METHOD'),
        _api.fetchMasterDataValues(
            accessToken: widget.accessToken, code: 'TRANSPORT_MODE'),
        _api.fetchMasterDataValues(
            accessToken: widget.accessToken, code: 'DELIVERY_PAYMENT_MODE'),
      ]);
      if (!mounted) return;
      setState(() {
        _logistics = results[0] as List<ExternalLogistic>;
        _shippingMethods = results[1] as List<MasterDataValue>;
        _transportModes = results[2] as List<MasterDataValue>;
        _paymentModes = results[3] as List<MasterDataValue>;
        if (_paymentModes.isNotEmpty &&
            !_paymentModes.any((item) => item.value == _paymentMode)) {
          _paymentMode = _paymentModes.first.value;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MasterDataValue> get _availableShippingMethods {
    final supported = _selectedLogistic?.shippingServices ?? const [];
    return supported.isEmpty
        ? _shippingMethods
        : _shippingMethods
            .where((method) => supported.contains(method.value))
            .toList();
  }

  List<MasterDataValue> get _availableTransportModes {
    final supported = _selectedLogistic?.transportModes ?? const [];
    return supported.isEmpty
        ? _transportModes
        : _transportModes
            .where((mode) => supported.contains(mode.value))
            .toList();
  }

  Future<void> _selectLogistic(ExternalLogistic? logistic) async {
    final requestId = ++_warehouseRequestId;
    final embeddedWarehouses = logistic?.warehouses ?? const [];
    setState(() {
      _selectedLogistic = logistic;
      _selectedWarehouse = null;
      _warehouses = embeddedWarehouses;
      _loadingWarehouses = logistic != null && embeddedWarehouses.isEmpty;
      if (!_availableShippingMethods
          .any((item) => item.value == _shippingService)) {
        _shippingService = null;
      }
      if (!_availableTransportModes
          .any((item) => item.value == _transportMode)) {
        _transportMode = null;
      }
      final trackingUrl = logistic?.trackingUrl?.trim();
      _trackingUrl.text =
          trackingUrl == null || trackingUrl.isEmpty ? '' : trackingUrl;
    });

    if (logistic == null || embeddedWarehouses.isNotEmpty) return;

    try {
      final warehouses = await _api.fetchWarehouses(
        accessToken: widget.accessToken,
        externalLogisticId: logistic.id,
      );
      if (!mounted ||
          requestId != _warehouseRequestId ||
          _selectedLogistic?.id != logistic.id) {
        return;
      }
      setState(() {
        _warehouses = warehouses;
        _loadingWarehouses = false;
      });
    } catch (error) {
      if (!mounted ||
          requestId != _warehouseRequestId ||
          _selectedLogistic?.id != logistic.id) {
        return;
      }
      setState(() {
        _warehouses = const [];
        _loadingWarehouses = false;
      });
      showFulfillmentMessage(context, error.toString(), isError: true);
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showAutoDismissDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      controller.text = fulfillmentDateOnly(picked);
    }
  }

  String? _numberError(String? value, {bool integer = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return (integer ? int.tryParse(text) : num.tryParse(text)) == null
        ? 'sales_order_details.msg_enter_valid_number'.tr
        : null;
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (_selectedLogistic == null) {
      showFulfillmentMessage(
          context, 'sales_order_details.msg_select_logistic'.tr,
          isError: true);
      return;
    }
    if (_isCodPaymentMode && _codAmount.text.trim().isEmpty) {
      showFulfillmentMessage(
          context, 'sales_order_details.msg_cod_amount_required'.tr,
          isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'external_logistic_id': _selectedLogistic!.id,
      };
      putFulfillmentString(payload, 'payment_mode', _paymentMode);
      putFulfillmentString(payload, 'shipping_service', _shippingService);
      putFulfillmentString(payload, 'transport_mode', _transportMode);
      if (_selectedWarehouse != null) {
        payload['warehouse_id'] = _selectedWarehouse!.id;
      }
      if (_isCodPaymentMode) {
        putFulfillmentNumber(payload, 'cod_amount', _codAmount.text);
      }
      putFulfillmentInt(payload, 'package_count', _packageCount.text);
      putFulfillmentNumber(payload, 'weight', _weight.text);
      putFulfillmentNumber(payload, 'length', _length.text);
      putFulfillmentNumber(payload, 'breadth', _breadth.text);
      putFulfillmentNumber(payload, 'height', _height.text);
      putFulfillmentNumber(payload, 'shipping_charge', _shippingCharge.text);
      putFulfillmentString(payload, 'dispatch_date', _dispatchDate.text);
      putFulfillmentString(
          payload, 'expected_delivery_at', _expectedDelivery.text);
      putFulfillmentString(payload, 'tracking_url', _trackingUrl.text);
      putFulfillmentString(payload, 'external_shipment_id', _shipmentId.text);
      putFulfillmentString(payload, 'remarks', _remarks.text);

      await _api.createExternalDelivery(
        accessToken: widget.accessToken,
        orderNumber: widget.orderNumber,
        payload: payload,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted)
        showFulfillmentMessage(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FulfillmentDialogFrame(
      title: 'sales_order_details.title_create_delivery'.tr,
      canDismiss: !_submitting,
      footer: _loading || _loadError != null
          ? null
          : FulfillmentDialogActions(
              submitting: _submitting,
              submitLabel: 'sales_order_details.btn_create_delivery'.tr,
              onSubmit: _submit,
            ),
      child: _loading
          ? const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()))
          : _loadError != null
              ? FulfillmentLoadFailure(
                  message: _loadError!, onRetry: _loadOptions)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FulfillmentFormGrid(children: [
                        fulfillmentDropdown<ExternalLogistic>(
                          label:
                              'sales_order_details.label_shipping_partner'.tr,
                          value: _selectedLogistic,
                          items: _logistics,
                          itemLabel: (item) => item.name,
                          onChanged: _selectLogistic,
                          required: true,
                        ),
                        fulfillmentDropdown<MasterDataValue>(
                          label: 'sales_order_details.label_shipping_method'.tr,
                          value: _availableShippingMethods
                                  .any((item) => item.value == _shippingService)
                              ? _availableShippingMethods.firstWhere(
                                  (item) => item.value == _shippingService)
                              : null,
                          items: _availableShippingMethods,
                          itemLabel: (item) => item.label,
                          onChanged: (value) =>
                              setState(() => _shippingService = value?.value),
                        ),
                        fulfillmentDropdown<MasterDataValue>(
                          label: 'sales_order_details.label_transport_mode'.tr,
                          value: _availableTransportModes
                                  .any((item) => item.value == _transportMode)
                              ? _availableTransportModes.firstWhere(
                                  (item) => item.value == _transportMode)
                              : null,
                          items: _availableTransportModes,
                          itemLabel: (item) => item.label,
                          onChanged: (value) =>
                              setState(() => _transportMode = value?.value),
                        ),
                        fulfillmentDropdown<ExternalLogisticWarehouse>(
                          label:
                              'sales_order_details.label_pickup_warehouse'.tr,
                          value: _selectedWarehouse,
                          items: _warehouses,
                          itemLabel: (item) => item.name,
                          onChanged: (value) =>
                              setState(() => _selectedWarehouse = value),
                          enabled:
                              _selectedLogistic != null && !_loadingWarehouses,
                        ),
                        fulfillmentTextField(
                          controller: _weight,
                          label: 'sales_order_details.label_weight_kg'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        fulfillmentTextField(
                          controller: _packageCount,
                          label: 'sales_order_details.label_package_count'.tr,
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              _numberError(value, integer: true),
                        ),
                        fulfillmentTextField(
                          controller: _length,
                          label: 'sales_order_details.label_length_cm'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        fulfillmentTextField(
                          controller: _breadth,
                          label: 'sales_order_details.label_breadth_cm'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        fulfillmentTextField(
                          controller: _height,
                          label: 'sales_order_details.label_height_cm'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        fulfillmentTextField(
                          controller: _trackingUrl,
                          label: 'sales_order_details.label_tracking_url'.tr,
                          keyboardType: TextInputType.url,
                        ),
                        fulfillmentTextField(
                          controller: _shipmentId,
                          label: 'sales_order_details.label_awb_number'.tr,
                        ),
                        fulfillmentTextField(
                          controller: _shippingCharge,
                          label: 'sales_order_details.label_shipping_charge'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        fulfillmentDateField(
                          controller: _dispatchDate,
                          label: 'sales_order_details.label_dispatch_date'.tr,
                          onTap: () => _pickDate(_dispatchDate),
                        ),
                        fulfillmentDateField(
                          controller: _expectedDelivery,
                          label:
                              'sales_order_details.label_expected_delivery'.tr,
                          onTap: () => _pickDate(_expectedDelivery),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      fulfillmentTextField(
                        controller: _remarks,
                        label: 'sales_order_details.label_remarks'.tr,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      FulfillmentFormGrid(children: [
                        fulfillmentDropdown<MasterDataValue>(
                          label: 'sales_order_details.label_payment_mode'.tr,
                          value: _paymentModes
                                  .any((item) => item.value == _paymentMode)
                              ? _paymentModes.firstWhere(
                                  (item) => item.value == _paymentMode)
                              : null,
                          items: _paymentModes,
                          itemLabel: (item) => item.label,
                          onChanged: (value) => setState(() {
                            if (value != null) {
                              _paymentMode = value.value;
                            }
                          }),
                        ),
                        if (_isCodPaymentMode)
                          fulfillmentTextField(
                            controller: _codAmount,
                            label: 'sales_order_details.label_cod_amount'.tr,
                            required: true,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: _numberError,
                          ),
                      ]),
                    ],
                  ),
                ),
    );
  }
}
