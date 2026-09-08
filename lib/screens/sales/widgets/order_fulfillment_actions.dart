import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/models/order_fulfillment.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/order_fulfillment_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool? _canManage;

  @override
  void initState() {
    super.initState();
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
    final token = context.read<AuthModel>().token;
    if (token == null || token.isEmpty) {
      _showMessage(context, 'sales_order_details.msg_session_expired'.tr,
          isError: true);
      return;
    }

    if (widget.action == OrderFulfillmentAction.packing &&
        !_isPackableStatus(widget.orderStatus)) {
      _showMessage(context, 'sales_order_details.msg_packing_order_status'.tr,
          isError: true);
      return;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) =>
          widget.action == OrderFulfillmentAction.externalDelivery
              ? _ExternalDeliveryDialog(
                  orderNumber: widget.orderNumber,
                  accessToken: token,
                )
              : _PackingDialog(
                  orderNumber: widget.orderNumber,
                  accessToken: token,
                  packing: widget.packing,
                ),
    );
    if (saved == true && mounted) {
      _showMessage(
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

class _ExternalDeliveryDialog extends StatefulWidget {
  final String orderNumber;
  final String accessToken;

  const _ExternalDeliveryDialog({
    required this.orderNumber,
    required this.accessToken,
  });

  @override
  State<_ExternalDeliveryDialog> createState() =>
      _ExternalDeliveryDialogState();
}

class _ExternalDeliveryDialogState extends State<_ExternalDeliveryDialog> {
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
      _showMessage(context, error.toString(), isError: true);
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      controller.text = _dateOnly(picked);
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
      _showMessage(context, 'sales_order_details.msg_select_logistic'.tr,
          isError: true);
      return;
    }
    if (_isCodPaymentMode && _codAmount.text.trim().isEmpty) {
      _showMessage(context, 'sales_order_details.msg_cod_amount_required'.tr,
          isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final payload = <String, dynamic>{
        'external_logistic_id': _selectedLogistic!.id,
      };
      _putString(payload, 'payment_mode', _paymentMode);
      _putString(payload, 'shipping_service', _shippingService);
      _putString(payload, 'transport_mode', _transportMode);
      if (_selectedWarehouse != null) {
        payload['warehouse_id'] = _selectedWarehouse!.id;
      }
      if (_isCodPaymentMode) {
        _putNumber(payload, 'cod_amount', _codAmount.text);
      }
      _putInt(payload, 'package_count', _packageCount.text);
      _putNumber(payload, 'weight', _weight.text);
      _putNumber(payload, 'length', _length.text);
      _putNumber(payload, 'breadth', _breadth.text);
      _putNumber(payload, 'height', _height.text);
      _putNumber(payload, 'shipping_charge', _shippingCharge.text);
      _putString(payload, 'dispatch_date', _dispatchDate.text);
      _putString(payload, 'expected_delivery_at', _expectedDelivery.text);
      _putString(payload, 'tracking_url', _trackingUrl.text);
      _putString(payload, 'external_shipment_id', _shipmentId.text);
      _putString(payload, 'remarks', _remarks.text);

      await _api.createExternalDelivery(
        accessToken: widget.accessToken,
        orderNumber: widget.orderNumber,
        payload: payload,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FulfillmentDialogFrame(
      title: 'sales_order_details.title_create_delivery'.tr,
      canDismiss: !_submitting,
      footer: _loading || _loadError != null
          ? null
          : _DialogActions(
              submitting: _submitting,
              submitLabel: 'sales_order_details.btn_create_delivery'.tr,
              onSubmit: _submit,
            ),
      child: _loading
          ? const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()))
          : _loadError != null
              ? _LoadFailure(message: _loadError!, onRetry: _loadOptions)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FormGrid(children: [
                        _dropdown<ExternalLogistic>(
                          label:
                              'sales_order_details.label_shipping_partner'.tr,
                          value: _selectedLogistic,
                          items: _logistics,
                          itemLabel: (item) => item.name,
                          onChanged: _selectLogistic,
                          required: true,
                        ),
                        _dropdown<MasterDataValue>(
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
                        _dropdown<MasterDataValue>(
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
                        _dropdown<ExternalLogisticWarehouse>(
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
                        _textField(
                          controller: _weight,
                          label: 'sales_order_details.label_weight_kg'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        _textField(
                          controller: _packageCount,
                          label: 'sales_order_details.label_package_count'.tr,
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              _numberError(value, integer: true),
                        ),
                        _textField(
                          controller: _length,
                          label: 'sales_order_details.label_length_cm'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        _textField(
                          controller: _breadth,
                          label: 'sales_order_details.label_breadth_cm'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        _textField(
                          controller: _height,
                          label: 'sales_order_details.label_height_cm'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        _textField(
                          controller: _trackingUrl,
                          label: 'sales_order_details.label_tracking_url'.tr,
                          keyboardType: TextInputType.url,
                        ),
                        _textField(
                          controller: _shipmentId,
                          label: 'sales_order_details.label_awb_number'.tr,
                        ),
                        _textField(
                          controller: _shippingCharge,
                          label: 'sales_order_details.label_shipping_charge'.tr,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: _numberError,
                        ),
                        _dateField(
                          controller: _dispatchDate,
                          label: 'sales_order_details.label_dispatch_date'.tr,
                          onTap: () => _pickDate(_dispatchDate),
                        ),
                        _dateField(
                          controller: _expectedDelivery,
                          label:
                              'sales_order_details.label_expected_delivery'.tr,
                          onTap: () => _pickDate(_expectedDelivery),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _textField(
                        controller: _remarks,
                        label: 'sales_order_details.label_remarks'.tr,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      _FormGrid(children: [
                        _dropdown<MasterDataValue>(
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
                          _textField(
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

class _PackingDialog extends StatefulWidget {
  final String orderNumber;
  final String accessToken;
  final OrderDetailsModelDataPacking? packing;

  const _PackingDialog({
    required this.orderNumber,
    required this.accessToken,
    this.packing,
  });

  @override
  State<_PackingDialog> createState() => _PackingDialogState();
}

class _PackingDialogState extends State<_PackingDialog> {
  static const _maxPhotoBytes = 20 * 1024 * 1024;
  static const _maxVideoBytes = 100 * 1024 * 1024;

  final _api = OrderFulfillmentProvider();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _packerName;
  late final TextEditingController _packedAt;
  late final String? _originalPackedAt;
  bool _packedAtChanged = false;
  List<PackingStaff> _staff = const [];
  int? _selectedStaffId;
  List<PlatformFile> _newPhotos = [];
  PlatformFile? _newVideo;
  final Set<String> _photosToDelete = <String>{};
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _packerName =
        TextEditingController(text: widget.packing?.packedByName ?? '');
    _originalPackedAt = widget.packing?.packedAt?.trim();
    _packedAt =
        TextEditingController(text: _dateTimeDisplay(_originalPackedAt));
    _selectedStaffId = widget.packing?.packedByUserId;
    _loadStaff();
  }

  @override
  void dispose() {
    _packerName.dispose();
    _packedAt.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final staff =
          await _api.fetchPackingStaff(accessToken: widget.accessToken);
      if (!mounted) return;
      setState(() {
        _staff = staff;
        if (_staff.every((person) => person.id != _selectedStaffId)) {
          _selectedStaffId = null;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPackedAt() async {
    final existing =
        _parsePackedAt(_packedAt.text) ?? DateHelper.nowInConfiguredTimeZone();
    final date = await showDatePicker(
      context: context,
      initialDate: existing,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existing),
    );
    if (time == null || !mounted) return;
    final result =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _packedAt.text = _dateTimeInput(result);
      _packedAtChanged = true;
    });
  }

  Future<void> _choosePhotos() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final oversized = result.files.where((file) => file.size > _maxPhotoBytes);
    if (oversized.isNotEmpty) {
      _showMessage(context, 'sales_order_details.msg_photo_size_limit'.tr,
          isError: true);
      return;
    }
    setState(() => _newPhotos = [..._newPhotos, ...result.files]);
  }

  Future<void> _chooseVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'webm'],
    );
    final file =
        result != null && result.files.isNotEmpty ? result.files.first : null;
    if (file == null || !mounted) return;
    if (file.size > _maxVideoBytes) {
      _showMessage(context, 'sales_order_details.msg_video_size_limit'.tr,
          isError: true);
      return;
    }
    setState(() => _newVideo = file);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    final packedAtInput = _parsePackedAt(_packedAt.text);
    final packedAt = !_packedAtChanged &&
            _originalPackedAt != null &&
            _originalPackedAt!.isNotEmpty
        ? _originalPackedAt
        : DateHelper.configuredDateTimeToUtcIso(_packedAt.text);
    if (packedAtInput == null || packedAt == null) {
      _showMessage(context, 'sales_order_details.msg_packed_at_required'.tr,
          isError: true);
      return;
    }
    if (_selectedStaffId == null && _packerName.text.trim().isEmpty) {
      _showMessage(context, 'sales_order_details.msg_packer_required'.tr,
          isError: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await _api.savePacking(
        accessToken: widget.accessToken,
        orderNumber: widget.orderNumber,
        packedByUserId: _selectedStaffId,
        packedByName: _packerName.text,
        packedAt: packedAt,
        photos: _newPhotos,
        video: _newVideo,
        photosToDelete: _photosToDelete.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showMessage(context, error.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FulfillmentDialogFrame(
      title: 'sales_order_details.title_packing'.tr,
      canDismiss: !_submitting,
      footer: _loading || _loadError != null
          ? null
          : _DialogActions(
              submitting: _submitting,
              submitLabel: 'sales_order_details.btn_save_packing'.tr,
              onSubmit: _submit,
            ),
      child: _loading
          ? const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()))
          : _loadError != null
              ? _LoadFailure(message: _loadError!, onRetry: _loadStaff)
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _FormGrid(children: [
                        _dropdown<PackingStaff>(
                          label: 'sales_order_details.label_packed_by_staff'.tr,
                          value: _staff.any(
                                  (person) => person.id == _selectedStaffId)
                              ? _staff.firstWhere(
                                  (person) => person.id == _selectedStaffId)
                              : null,
                          items: _staff,
                          itemLabel: (person) => person.name,
                          onChanged: (staff) {
                            setState(() {
                              _selectedStaffId = staff?.id;
                              if (staff != null) {
                                _packerName.text = staff.name;
                              }
                            });
                          },
                        ),
                        _textField(
                          controller: _packerName,
                          label: 'sales_order_details.label_packer_name'.tr,
                        ),
                        _dateField(
                          controller: _packedAt,
                          label:
                              'sales_order_details.label_packed_date_time'.tr,
                          onTap: _pickPackedAt,
                          required: true,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _filePickerCard(
                        title:
                            'sales_order_details.label_add_packing_photos'.tr,
                        buttonLabel: 'sales_order_details.btn_choose_photos'.tr,
                        icon: Icons.add_photo_alternate_outlined,
                        onPick: _choosePhotos,
                        files: _newPhotos,
                        showImagePreviews: true,
                        onRemove: (index) =>
                            setState(() => _newPhotos.removeAt(index)),
                      ),
                      if ((widget.packing?.packingPhotoPaths ?? const [])
                          .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _existingPhotos(),
                      ],
                      const SizedBox(height: 12),
                      _filePickerCard(
                        title: 'sales_order_details.label_packing_video'.tr,
                        buttonLabel: 'sales_order_details.btn_choose_video'.tr,
                        icon: Icons.video_file_outlined,
                        onPick: _chooseVideo,
                        files: _newVideo == null ? const [] : [_newVideo!],
                        onRemove: (_) => setState(() => _newVideo = null),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _existingPhotos() {
    final storedPaths = widget.packing?.packingPhotoPaths ?? const <String>[];
    final displayUrls = widget.packing?.packingPhotos ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('sales_order_details.label_existing_packing_photos'.tr,
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        ...storedPaths.asMap().entries.map(
          (entry) {
            final displayUrl =
                entry.key < displayUrls.length ? displayUrls[entry.key] : null;
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text((displayUrl ?? entry.value).split('/').last),
              secondary: _RemotePackingPhotoThumbnail(imageUrl: displayUrl),
              value: _photosToDelete.contains(entry.value),
              onChanged: (selected) => setState(() {
                if (selected == true) {
                  _photosToDelete.add(entry.value);
                } else {
                  _photosToDelete.remove(entry.value);
                }
              }),
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        ),
        Text('sales_order_details.msg_select_photos_to_delete'.tr,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FulfillmentDialogFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;
  final bool canDismiss;

  const _FulfillmentDialogFrame({
    required this.title,
    required this.child,
    this.footer,
    this.canDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    return PopScope(
      canPop: canDismiss,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? screenSize.width - 48 : 920,
            maxHeight: screenSize.height - 48,
          ),
          child: BuildBoxShadowContainer(
            circleRadius: 16,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.27,
                            ColorManager.textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: canDismiss
                            ? () => Navigator.of(context).pop()
                            : null,
                        icon: const Icon(Icons.close, color: Colors.grey),
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: child,
                  ),
                ),
                if (footer != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: footer!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormGrid extends StatelessWidget {
  final List<Widget> children;

  const _FormGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 620;
        final width =
            twoColumns ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class _LoadFailure extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _LoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              CustomRoundButton(
                title: 'sales_order_details.btn_retry'.tr,
                fct: onRetry,
                height: 36,
                width: 120,
                fontSize: FontSize.s11,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 17),
              ),
            ],
          ),
        ),
      );
}

class _DialogActions extends StatelessWidget {
  final bool submitting;
  final String submitLabel;
  final VoidCallback onSubmit;

  const _DialogActions({
    required this.submitting,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CustomRoundButton(
            title: 'sales_order_details.btn_cancel'.tr,
            fct: submitting ? () {} : () => Navigator.of(context).pop(),
            height: 40,
            width: 110,
            fontSize: FontSize.s12,
            boxColor: Colors.white,
            borderColor: ColorManager.kPrimaryColor,
            textColor: ColorManager.kPrimaryColor,
          ),
          const SizedBox(width: 12),
          CustomRoundButton(
            title: submitLabel,
            fct: onSubmit,
            height: 40,
            width: 160,
            fontSize: FontSize.s12,
            isLoading: submitting,
          ),
        ],
      );
}

Widget _dropdown<T>({
  required String label,
  required T? value,
  required List<T> items,
  required String Function(T) itemLabel,
  required ValueChanged<T?> onChanged,
  bool required = false,
  bool enabled = true,
}) =>
    _LabeledField(
      label: label,
      required: required,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _fieldDecoration(),
        child: DropdownButtonFormField<T>(
          key: ValueKey(value),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: label,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child:
                        Text(itemLabel(item), overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: !enabled || items.isEmpty ? null : onChanged,
          validator: required
              ? (selected) => selected == null
                  ? 'sales_order_details.msg_required_field'.tr
                  : null
              : null,
        ),
      ),
    );

Widget _textField({
  required TextEditingController controller,
  required String label,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
  int maxLines = 1,
  bool required = false,
}) =>
    _LabeledField(
      label: label,
      required: required,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator ??
            (required
                ? (value) => (value == null || value.trim().isEmpty)
                    ? 'sales_order_details.msg_required_field'.tr
                    : null
                : null),
        decoration: _textFieldDecoration(label),
      ),
    );

Widget _dateField({
  required TextEditingController controller,
  required String label,
  required VoidCallback onTap,
  bool required = false,
}) =>
    _LabeledField(
      label: label,
      required: required,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        validator: required
            ? (value) => (value == null || value.trim().isEmpty)
                ? 'sales_order_details.msg_required_field'.tr
                : null
            : null,
        decoration: _textFieldDecoration(label).copyWith(
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
      ),
    );

class _LabeledField extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;

  const _LabeledField({
    required this.label,
    required this.required,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s13,
                0.27,
                ColorManager.textColor,
              ),
              children: [
                TextSpan(text: label),
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      );
}

BoxDecoration _fieldDecoration() => BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    );

InputDecoration _textFieldDecoration(String hintText) => InputDecoration(
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColorManager.kPrimaryColor),
      ),
    );

Widget _filePickerCard({
  required String title,
  required String buttonLabel,
  required IconData icon,
  required VoidCallback onPick,
  required List<PlatformFile> files,
  required ValueChanged<int> onRemove,
  bool showImagePreviews = false,
}) =>
    Builder(
      builder: (context) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              CustomRoundButton(
                title: buttonLabel,
                fct: onPick,
                height: 38,
                width: 160,
                fontSize: FontSize.s11,
                boxColor: Colors.white,
                borderColor: ColorManager.kPrimaryColor,
                textColor: ColorManager.kPrimaryColor,
                icon: Icon(icon, color: ColorManager.kPrimaryColor, size: 17),
              ),
              if (files.isNotEmpty) ...[
                const SizedBox(height: 8),
                ...files.asMap().entries.map(
                      (entry) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: showImagePreviews
                            ? _LocalPackingPhotoThumbnail(file: entry.value)
                            : null,
                        title: Text(entry.value.name),
                        subtitle: Text(_fileSize(entry.value.size)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => onRemove(entry.key),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );

class _LocalPackingPhotoThumbnail extends StatelessWidget {
  final PlatformFile file;

  const _LocalPackingPhotoThumbnail({required this.file});

  @override
  Widget build(BuildContext context) {
    final path = file.path;
    if (path == null || path.isEmpty) {
      return const _PackingPhotoThumbnailPlaceholder();
    }

    return _PackingPhotoThumbnail(
      child: Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PackingPhotoThumbnailPlaceholder(),
      ),
    );
  }
}

class _RemotePackingPhotoThumbnail extends StatelessWidget {
  final String? imageUrl;

  const _RemotePackingPhotoThumbnail({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return const _PackingPhotoThumbnailPlaceholder();
    }

    return _PackingPhotoThumbnail(
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const _PackingPhotoThumbnailPlaceholder(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }
}

class _PackingPhotoThumbnail extends StatelessWidget {
  final Widget child;

  const _PackingPhotoThumbnail({required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(height: 44, width: 44, child: child),
      );
}

class _PackingPhotoThumbnailPlaceholder extends StatelessWidget {
  const _PackingPhotoThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image_not_supported_outlined, size: 20),
      );
}

void _putString(Map<String, dynamic> payload, String key, String? value) {
  final text = value?.trim();
  if (text != null && text.isNotEmpty) payload[key] = text;
}

void _putNumber(Map<String, dynamic> payload, String key, String value) {
  final parsed = num.tryParse(value.trim());
  if (parsed != null) payload[key] = parsed;
}

void _putInt(Map<String, dynamic> payload, String key, String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed != null) payload[key] = parsed;
}

String _dateOnly(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _dateTimeDisplay(String? value) {
  if (value == null || value.trim().isEmpty) return '';
  return DateHelper.formatISODateTimeForInput(value);
}

String _dateTimeInput(DateTime date) =>
    '${_dateOnly(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

DateTime? _parsePackedAt(String value) {
  final normalized = value.trim().replaceFirst(' ', 'T');
  return DateTime.tryParse(normalized);
}

String _fileSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

void _showMessage(BuildContext context, String message,
    {bool isError = false}) {
  if (isError) {
    showScaffoldError(context: context, message: message);
  } else {
    showScaffold(context: context, message: message);
  }
}
