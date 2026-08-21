import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/components/build_dialog_box.dart'
    hide showLoadingOverlay, hideLoadingOverlay;
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/helpers/purchase_return_pricing.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/models/purchase_order_model.dart';
import 'package:pos_machine/models/purchase_return_model.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/purchase_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/purchase/widgets/purchase_orders_responsive.dart';
import 'package:provider/provider.dart';

class _ReturnLineItem {
  final ReturnableItem source;
  final double unitPrice;
  double quantity;
  String reason;

  _ReturnLineItem({
    required this.source,
    required this.unitPrice,
    required this.quantity,
    this.reason = '',
  });

  double get amount => PurchaseReturnPricing.roundCurrency(quantity * unitPrice);
}

class CreatePurchaseReturnScreen extends StatefulWidget {
  const CreatePurchaseReturnScreen({super.key});

  @override
  State<CreatePurchaseReturnScreen> createState() =>
      _CreatePurchaseReturnScreenState();
}

class _CreatePurchaseReturnScreenState
    extends State<CreatePurchaseReturnScreen> {
  final SideBarController sideBarController = Get.put(SideBarController());

  // Step management
  bool _voucherSelected = false;
  PurchaseOrderData? _selectedVoucher;

  // Loading states
  bool _isLoadingVouchers = true;
  bool _isLoadingItems = false;
  bool _isSubmitting = false;
  String? _itemsLoadError;

  // Return items
  final List<_ReturnLineItem> _returnItems = [];
  DateTime _returnDate = DateTime.now();

  // Payment
  MasterDataValue? _selectedPaymentMethod;
  final TextEditingController _paidAmountController = TextEditingController();
  bool _paidAmountManuallyEdited = false;
  List<MasterDataValue> _paymentMethods = [];
  bool _isLoadingPaymentMethods = false;

  @override
  void initState() {
    super.initState();
    _loadVouchers();
    _loadPaymentMethods();
  }

  @override
  void dispose() {
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() => _isLoadingPaymentMethods = true);
    try {
      final masterDataProvider =
          Provider.of<MasterDataProvider>(context, listen: false);
      final cachedMethods = masterDataProvider.paymentMethods;
      final methods = (cachedMethods != null && cachedMethods.isNotEmpty)
          ? cachedMethods
          : (await masterDataProvider.fetchPaymentMethods() ??
              <MasterDataValue>[]);
      if (mounted) {
        setState(() {
          _paymentMethods = methods;
          _isLoadingPaymentMethods = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPaymentMethods = false);
    }
  }

  Future<void> _loadVouchers({int page = 1}) async {
    setState(() => _isLoadingVouchers = true);
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final token = Provider.of<AuthModel>(context, listen: false).token;
      await provider.listPurchaseOrders(accessToken: token ?? '', page: page);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingVouchers = false);
  }

  Future<void> _onVoucherSelected(PurchaseOrderData voucher) async {
    if (voucher.id == null) return;
    setState(() {
      _selectedVoucher = voucher;
      _voucherSelected = true;
      _isLoadingItems = true;
      _itemsLoadError = null;
      _returnItems.clear();
    });
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final token = Provider.of<AuthModel>(context, listen: false).token;
      await provider.fetchReturnableItems(
        accessToken: token ?? '',
        purchaseVoucherId: voucher.id!,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _itemsLoadError = _errorMessage(e);
          _isLoadingItems = false;
        });
      }
      return;
    }
    if (mounted) setState(() => _isLoadingItems = false);
  }

  String _errorMessage(Object error) {
    final message = error.toString();
    return message
        .replaceFirst('HttpException: ', '')
        .replaceFirst('Exception: ', '');
  }

  Future<void> _retryLoadReturnableItems() async {
    final voucherId = _selectedVoucher?.id;
    if (voucherId == null || _isLoadingItems) return;

    setState(() {
      _isLoadingItems = true;
      _itemsLoadError = null;
    });
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final token = Provider.of<AuthModel>(context, listen: false).token;
      await provider.fetchReturnableItems(
        accessToken: token ?? '',
        purchaseVoucherId: voucherId,
      );
    } catch (e) {
      if (mounted) setState(() => _itemsLoadError = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoadingItems = false);
    }
  }

  void _showReturnItemDialog(ReturnableItem item) {
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    final maxQty = item.returnableQuantity ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item.productName ?? '-',
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s16,
            0.22,
            ColorManager.textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'purchase_return.returnable_qty'.tr}: ${_formatQty(maxQty)}',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.15,
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: InputDecoration(
                labelText: 'purchase_return.return_qty'.tr,
                hintText: 'purchase_return.enter_qty'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'purchase_return.reason'.tr,
                hintText: 'purchase_return.enter_reason'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('confirmed_orders.close'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
            ),
            onPressed: () {
              final qty = double.tryParse(qtyController.text) ?? 0;
              if (qty <= 0) {
                showScaffoldError(
                  context: context,
                  message: 'purchase_return.qty_must_be_positive'.tr,
                );
                return;
              }
              if (qty > maxQty) {
                showScaffoldError(
                  context: context,
                  message:
                      '${'purchase_return.qty_exceeds'.tr} ${_formatQty(maxQty)}',
                );
                return;
              }
              final existing = _returnItems.indexWhere(
                (e) => e.source.purchaseItemId == item.purchaseItemId,
              );
              setState(() {
                if (existing >= 0) {
                  _returnItems[existing].quantity = qty;
                  _returnItems[existing].reason = reasonController.text.trim();
                } else {
                  _returnItems.add(_ReturnLineItem(
                    source: item,
                    unitPrice: _returnUnitPrice(item),
                    quantity: qty,
                    reason: reasonController.text.trim(),
                  ));
                }
                _updatePaidAmount();
              });
              Navigator.pop(ctx);
            },
            child: Text(
              'purchase_return.add_to_return'.tr,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _removeReturnItem(int index) {
    setState(() {
      _returnItems.removeAt(index);
      _updatePaidAmount();
    });
  }

  Future<void> _pickReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _returnDate = picked);
    }
  }

  Future<void> _submitReturn() async {
    if (_isSubmitting) return;
    if (_returnItems.isEmpty || _selectedVoucher?.id == null) return;

    if (_selectedPaymentMethod != null) {
      final amount = double.tryParse(_paidAmountController.text.trim()) ?? 0;
      if (amount <= 0 || amount > _totalReturnAmount) {
        showScaffoldError(
          context: context,
          message:
              '${'purchase_return.return_amount'.tr}: 0 - ${_totalReturnAmount.toStringAsFixed(2)}',
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    final provider = Provider.of<PurchaseProvider>(context, listen: false);
    final token = Provider.of<AuthModel>(context, listen: false).token;

    final items = _returnItems.map((e) {
      final map = <String, dynamic>{
        'purchase_item_id': e.source.purchaseItemId,
        'quantity': e.quantity,
      };
      if (e.reason.isNotEmpty) map['reason'] = e.reason;
      return map;
    }).toList();

    final result = await provider.createPurchaseReturn(
      accessToken: token ?? '',
      purchaseVoucherId: _selectedVoucher!.id!,
      returnDate: DateFormat('yyyy-MM-dd').format(_returnDate),
      items: items,
      hasPayment: _selectedPaymentMethod != null,
      paidAmount: _selectedPaymentMethod != null
          ? double.tryParse(_paidAmountController.text.trim())
          : null,
      paymentMethod: _selectedPaymentMethod?.id.toString(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['status'] == 'success') {
      showScaffold(
        context: context,
        message: 'purchase_return.return_created'.tr,
      );
      sideBarController.index.value = 99;
    } else {
      showScaffoldError(
        context: context,
        message: result['message'] ?? 'purchase_return.err_create'.tr,
      );
    }
  }

  String _formatQty(double? value) {
    return PurchaseReturnPricing.formatQuantity(value);
  }

  double _returnUnitPrice(ReturnableItem item) {
    return PurchaseReturnPricing.unitPrice(
      item: item,
      voucher: _selectedVoucher,
    );
  }

  void _updatePaidAmount() {
    if (!_paidAmountManuallyEdited) {
      _paidAmountController.text = _totalReturnAmount.toStringAsFixed(2);
    }
  }

  double get _totalReturnAmount =>
      _returnItems.fold(0.0, (sum, e) => sum + e.amount);

  double get _totalReturnQty =>
      _returnItems.fold(0.0, (sum, e) => sum + e.quantity);

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'purchase_return.payment_details'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s13,
              0.20,
              ColorManager.kPrimaryColor,
            ),
          ),
          const SizedBox(height: 14),
            Text(
              'purchase_return.payment_method'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 6),
            if (_isLoadingPaymentMethods)
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ColorManager.kPrimaryColor,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _paymentMethods.map((method) {
                  final isSelected =
                      _selectedPaymentMethod?.id == method.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_selectedPaymentMethod?.id == method.id) {
                          _selectedPaymentMethod = null;
                        } else {
                          _selectedPaymentMethod = method;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ColorManager.kPrimaryColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? ColorManager.kPrimaryColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        method.description.isNotEmpty
                            ? method.description
                            : method.value,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s12,
                          0.15,
                          isSelected ? Colors.white : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 14),
            Text(
              'purchase_return.return_amount'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s12,
                0.2,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Consumer<AppSettingsProvider>(
              builder: (context, settings, _) {
                final currency = settings.appSettings?.currency ?? 'INR';
                return TextField(
                  controller: _paidAmountController,
                  onChanged: (_) => _paidAmountManuallyEdited = true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    prefixText: '$currency ',
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.15,
                    ColorManager.textColor,
                  ),
                );
              },
            ),
            const SizedBox(height: 6),
            Consumer<AppSettingsProvider>(
              builder: (context, settings, _) {
                final currency = settings.appSettings?.currency ?? 'INR';
                return Text(
                  '${'purchase_return.max_return_amount'.tr}: $currency ${_totalReturnAmount.toStringAsFixed(2)}',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s11,
                    0.15,
                    Colors.grey.shade500,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = purchaseOrdersIsPhone(context);

    return PurchaseOrdersListShell(
      onRefresh: _voucherSelected ? () async {} : _loadVouchers,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PurchaseOrdersPageHeader(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (_voucherSelected) {
                  setState(() {
                    _voucherSelected = false;
                    _selectedVoucher = null;
                    _returnItems.clear();
                    _selectedPaymentMethod = null;
                    _paidAmountController.clear();
                    _paidAmountManuallyEdited = false;
                  });
                } else {
                  sideBarController.index.value = 99;
                }
              },
              tooltip: 'purchase_return.back_to_list'.tr,
            ),
            title: _voucherSelected
                ? 'purchase_return.returnable_items'.tr
                : 'purchase_return.select_voucher'.tr,
            subtitle: _voucherSelected
                ? '${'purchase_return.voucher_number'.tr}: ${_selectedVoucher?.voucherNumber ?? ''} • ${_selectedVoucher?.supplier?.name ?? ''}'
                : 'purchase_return.select_voucher_hint'.tr,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _voucherSelected
                ? _buildReturnForm(isPhone)
                : _buildVoucherSelection(isPhone),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Voucher Selection ─────────────────────────────────────

  Widget _buildVoucherSelection(bool isPhone) {
    final provider = Provider.of<PurchaseProvider>(context);

    if (_isLoadingVouchers) {
      return const Center(
        child: CircularProgressIndicator(color: ColorManager.kPrimaryColor),
      );
    }

    if (provider.purchaseOrdersList.isEmpty) {
      return Center(
        child: Text(
          'purchase_order.no_orders_found'.tr,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.25,
            Colors.grey.shade600,
          ),
        ),
      );
    }

    final currentPg = provider.listPurchaseOrderCurrentPage;
    final totalPgs = provider.listPurchaseOrderTotalPages;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsetsDirectional.all(8),
            itemCount: provider.purchaseOrdersList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final voucher = provider.purchaseOrdersList[index];
              return _buildVoucherCard(voucher);
            },
          ),
        ),
        if (totalPgs > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (currentPg > 1)
                  TextButton(
                    onPressed: () => _loadVouchers(page: currentPg - 1),
                    child: const Text('Previous'),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('$currentPg / $totalPgs'),
                ),
                if (currentPg < totalPgs)
                  TextButton(
                    onPressed: () => _loadVouchers(page: currentPg + 1),
                    child: const Text('Next'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildVoucherCard(PurchaseOrderData voucher) {
    return InkWell(
      onTap: () => _onVoucherSelected(voucher),
      borderRadius: BorderRadius.circular(12),
      child: PurchaseOrdersContentCard(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${voucher.voucherNumber ?? voucher.id}',
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.20,
                      ColorManager.textColor,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: ColorManager.kPrimaryColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _voucherMetric(
                    'purchase_return.supplier'.tr,
                    voucher.supplier?.name ?? '-',
                  ),
                ),
                Expanded(
                  child: _voucherMetric(
                    'purchase_return.return_date'.tr,
                    voucher.purchaseDate ?? '-',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _voucherMetric(
                    'nav.store'.tr,
                    voucher.store?.name ?? '-',
                  ),
                ),
                Expanded(
                  child: Consumer<AppSettingsProvider>(
                    builder: (context, settings, _) {
                      final currency = settings.appSettings?.currency ?? 'INR';
                      return _voucherMetric(
                        'purchase_return.total_amount'.tr,
                        '$currency ${voucher.amountTotal ?? '0'}',
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _voucherMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.regular,
            FontSize.s10,
            0.15,
            Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.15,
            ColorManager.textColor,
          ),
        ),
      ],
    );
  }

  // ── Step 2: Return Form ───────────────────────────────────────────

  Widget _buildReturnForm(bool isPhone) {
    final provider = Provider.of<PurchaseProvider>(context);

    if (_isLoadingItems) {
      return const Center(
        child: CircularProgressIndicator(color: ColorManager.kPrimaryColor),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Returnable items section
          PurchaseOrdersSectionTitle(
            title: 'purchase_return.returnable_items'.tr,
          ),
          const SizedBox(height: 10),
          if (_itemsLoadError != null)
            PurchaseOrdersContentCard(
              padding: const EdgeInsetsDirectional.all(20),
              child: Column(
                children: [
                  Text(
                    _itemsLoadError!,
                    textAlign: TextAlign.center,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      FontSize.s13,
                      0.20,
                      Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomRoundButton(
                    title: 'restaurant.retry'.tr,
                    fct: _retryLoadReturnableItems,
                    fontSize: 12,
                    height: 40,
                    width: 120,
                  ),
                ],
              ),
            )
          else if (provider.returnableItemsList.isEmpty)
            PurchaseOrdersContentCard(
              padding: const EdgeInsetsDirectional.all(20),
              child: Center(
                child: Text(
                  'purchase_return.no_returnable_items'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s13,
                    0.20,
                    Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ...provider.returnableItemsList.map(_buildReturnableItemCard),

          // Return summary section
          if (_returnItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            PurchaseOrdersSectionTitle(
              title: 'purchase_return.return_summary'.tr,
            ),
            const SizedBox(height: 10),
            PurchaseOrdersContentCard(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Return date picker
                  InkWell(
                    onTap: _pickReturnDate,
                    child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: ColorManager.kPrimaryColor),
                          const SizedBox(width: 10),
                          Text(
                            '${'purchase_return.return_date'.tr}: ${DateFormat('yyyy-MM-dd').format(_returnDate)}',
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.20,
                              ColorManager.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Return items list
                  ...List.generate(_returnItems.length, (i) {
                    final item = _returnItems[i];
                    return Container(
                      margin: const EdgeInsetsDirectional.only(bottom: 10),
                      padding: const EdgeInsetsDirectional.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: Colors.grey.withOpacity(0.12)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.source.productName ?? '-',
                                  style: buildCustomStyle(
                                    FontWeightManager.semiBold,
                                    FontSize.s13,
                                    0.20,
                                    ColorManager.textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Consumer<AppSettingsProvider>(
                                  builder: (context, settings, _) {
                                    final currency =
                                        settings.appSettings?.currency ??
                                            'INR';
                                    return Text(
                                      '${'billing.table_qty'.tr}: ${_formatQty(item.quantity)} • '
                                      '$currency ${item.amount.toStringAsFixed(2)}',
                                      style: buildCustomStyle(
                                        FontWeightManager.regular,
                                        FontSize.s11,
                                        0.15,
                                        Colors.grey.shade600,
                                      ),
                                    );
                                  },
                                ),
                                if (item.reason.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    '${'purchase_return.reason'.tr}: ${item.reason}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s11,
                                      0.15,
                                      Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: Colors.red.shade400, size: 20),
                            onPressed: () => _removeReturnItem(i),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  const SizedBox(height: 8),
                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'purchase_return.total_return_qty'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.medium,
                          FontSize.s13,
                          0.20,
                          Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        _formatQty(_totalReturnQty),
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.20,
                          ColorManager.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Consumer<AppSettingsProvider>(
                    builder: (context, settings, _) {
                      final currency =
                          settings.appSettings?.currency ?? 'INR';
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'purchase_return.total_return_amount'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s13,
                              0.20,
                              Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            '$currency ${_totalReturnAmount.toStringAsFixed(2)}',
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.22,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentSection(),
                  const SizedBox(height: 16),
                  CustomRoundButton(
                    title: _isSubmitting
                        ? 'purchase_return.submitting'.tr
                        : 'purchase_return.submit_return'.tr,
                    fct: _isSubmitting ? () {} : _submitReturn,
                    fontSize: 14,
                    height: 48,
                    width: double.infinity,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildReturnableItemCard(ReturnableItem item) {
    final alreadyAdded = _returnItems
        .any((e) => e.source.purchaseItemId == item.purchaseItemId);
    final displayName =
        item.variantName != null && item.variantName!.isNotEmpty
            ? '${item.productName ?? ''} (${item.variantName})'
            : item.productName ?? '-';

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 10),
      child: PurchaseOrdersContentCard(
        padding: const EdgeInsetsDirectional.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s13,
                      0.20,
                      ColorManager.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Consumer<AppSettingsProvider>(
                    builder: (context, settings, _) {
                      final currency =
                          settings.appSettings?.currency ?? 'INR';
                      return Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${'purchase_return.purchased'.tr}: ${_formatQty(item.purchasedQuantity)}',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.15,
                              Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${'purchase_return.returned'.tr}: ${_formatQty(item.returnedQuantity)}',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.15,
                              Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${'purchase_return.returnable'.tr}: ${_formatQty(item.returnableQuantity)}',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.15,
                              ColorManager.kPrimaryColor,
                            ),
                          ),
                          Text(
                            '$currency ${_returnUnitPrice(item).toStringAsFixed(2)}/${'purchase_return.unit'.tr}',
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s11,
                              0.15,
                              Colors.grey.shade600,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: alreadyAdded
                      ? Colors.green.shade600
                      : ColorManager.kPrimaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: (item.returnableQuantity ?? 0) > 0
                    ? () => _showReturnItemDialog(item)
                    : null,
                child: Text(
                  alreadyAdded
                      ? 'purchase_return.added'.tr
                      : 'purchase_return.return_btn'.tr,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
