import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:provider/provider.dart';

class ChangeOrderStatusModal extends StatefulWidget {
  final String currentStatus;
  final String orderTotal;
  final Function({
    required String newStatus,
    double? refundAmount,
    String? paymentMethod,
    bool? deliveryChargeRefundable,
    String? deliveryLogistics,
  }) onConfirm;

  const ChangeOrderStatusModal({
    super.key,
    required this.currentStatus,
    required this.orderTotal,
    required this.onConfirm,
  });

  @override
  State<ChangeOrderStatusModal> createState() => _ChangeOrderStatusModalState();
}

class _ChangeOrderStatusModalState extends State<ChangeOrderStatusModal> {
  static const List<String> _statusOptions = [
    'init',
    'new',
    'confirmed',
    'processing',
    'shipped',
    'delivered',
    'cancelled',
  ];

  String? _selectedStatus;
  String? _selectedPaymentMethodId;
  bool _deliveryChargeRefundable = true;
  bool _isLoadingMethods = false;
  late final TextEditingController _refundAmountController;
  late final TextEditingController _deliveryLogisticsController;

  @override
  void initState() {
    super.initState();
    _refundAmountController = TextEditingController(text: '0');
    _deliveryLogisticsController = TextEditingController();

    // Pre-select current status
    if (_statusOptions
        .any((s) => s.toLowerCase() == widget.currentStatus.toLowerCase())) {
      _selectedStatus = _statusOptions.firstWhere(
          (s) => s.toLowerCase() == widget.currentStatus.toLowerCase());
    }

    if (_selectedStatus == 'cancelled') {
      _loadPaymentMethods();
    }
  }

  @override
  void dispose() {
    _refundAmountController.dispose();
    _deliveryLogisticsController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethods() async {
    setState(() {
      _isLoadingMethods = true;
    });
    final provider = Provider.of<MasterDataProvider>(context, listen: false);
    if (provider.paymentMethods == null || provider.paymentMethods!.isEmpty) {
      await provider.fetchPaymentMethods();
    }
    if (mounted) {
      setState(() {
        _isLoadingMethods = false;
      });
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: screenWidth < 600 ? screenWidth - 48 : 550,
        ),
        child: BuildBoxShadowContainer(
          padding: const EdgeInsets.all(24),
          circleRadius: 16,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Update Order Status",
                      style: buildCustomStyle(
                        FontWeightManager.semiBold,
                        FontSize.s20,
                        0.30,
                        ColorManager.textColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Status label
                RichText(
                  text: TextSpan(
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.27,
                      ColorManager.textColor,
                    ),
                    children: const [
                      TextSpan(text: 'Status'),
                      TextSpan(
                        text: '*',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Status dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: ColorManager.kPrimaryColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Select Status'),
                      value: _selectedStatus,
                      items: _statusOptions.map((String status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(_capitalize(status)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue;
                        });
                        if (newValue == 'cancelled') {
                          _loadPaymentMethods();
                        }
                      },
                    ),
                  ),
                ),

                // Conditional Fields for Logistics
                if (_selectedStatus == 'shipped' ||
                    _selectedStatus == 'delivered') ...[
                  const SizedBox(height: 20),
                  Text(
                    "Delivery Logistics",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.27,
                      ColorManager.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deliveryLogisticsController,
                    decoration: InputDecoration(
                      hintText: 'Enter logistics info',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: ColorManager.kPrimaryColor),
                      ),
                    ),
                  ),
                ],

                // Conditional Fields for Cancellation
                if (_selectedStatus == 'cancelled') ...[
                  const SizedBox(height: 20),
                  Text(
                    "Refund Payment Method",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.27,
                      ColorManager.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _isLoadingMethods
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator(),
                        ))
                      : Consumer<MasterDataProvider>(
                          builder: (context, provider, child) {
                            final methods = provider.paymentMethods ?? [];
                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text('Select Payment Method'),
                                  value: _selectedPaymentMethodId,
                                  items: methods.map((MasterDataValue method) {
                                    return DropdownMenuItem<String>(
                                      value: method.id.toString(),
                                      child: Text(method.value),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedPaymentMethodId = newValue;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 20),
                  Text(
                    "Refund Amount",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s14,
                      0.27,
                      ColorManager.textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _refundAmountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,3}$'),
                      ),
                    ],
                    decoration: InputDecoration(
                      hintText: 'Enter refund amount',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: ColorManager.kPrimaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Switch.adaptive(
                        value: _deliveryChargeRefundable,
                        activeColor: ColorManager.kPrimaryColor,
                        onChanged: (value) {
                          setState(() {
                            _deliveryChargeRefundable = value;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Delivery Charge Refundable",
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s14,
                          0.27,
                          ColorManager.textColor,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),

                // Buttons
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        if (_selectedStatus == null) {
                          showScaffoldError(
                            context: context,
                            message: "Please select a status",
                          );
                          return;
                        }

                        double? refundAmount;
                        if (_selectedStatus == 'cancelled') {
                          refundAmount = double.tryParse(
                              _refundAmountController.text.trim());
                          
                          if (_selectedPaymentMethodId == null) {
                            showScaffoldError(
                              context: context,
                              message: "Please select a refund payment method",
                            );
                            return;
                          }

                          if (refundAmount == null || refundAmount < 0) {
                            showScaffoldError(
                              context: context,
                              message: "Please enter a valid refund amount",
                            );
                            return;
                          }

                          final total = double.tryParse(widget.orderTotal.replaceAll(',', '').trim()) ?? 0;
                          if (refundAmount > total) {
                            showScaffoldError(
                              context: context,
                              message: "Refund amount cannot exceed order total ($total)",
                            );
                            return;
                          }
                        }

                        Navigator.of(context).pop();
                        widget.onConfirm(
                          newStatus: _selectedStatus!,
                          refundAmount: refundAmount,
                          paymentMethod: _selectedPaymentMethodId,
                          deliveryChargeRefundable: _selectedStatus == 'cancelled'
                              ? _deliveryChargeRefundable
                              : null,
                          deliveryLogistics:
                              _deliveryLogisticsController.text.trim().isNotEmpty
                                  ? _deliveryLogisticsController.text.trim()
                                  : null,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorManager.kPrimaryColor,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Update Status",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.27,
                          Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Cancel",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.27,
                          Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
