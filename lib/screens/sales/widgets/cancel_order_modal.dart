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

class CancelOrderModal extends StatefulWidget {
  final Function(
    String paymentMethodId,
    String refundAmount,
    bool deliveryChargeRefundable,
  ) onConfirm;
  final String initialRefundAmount;

  const CancelOrderModal({
    super.key,
    required this.onConfirm,
    required this.initialRefundAmount,
  });

  @override
  State<CancelOrderModal> createState() => _CancelOrderModalState();
}

class _CancelOrderModalState extends State<CancelOrderModal> {
  String? _selectedPaymentMethodId;
  bool _isLoading = true;
  bool _deliveryChargeRefundable = true;
  late final TextEditingController _refundAmountController;

  double? get _originalTotal =>
      double.tryParse(widget.initialRefundAmount.replaceAll(',', '').trim());

  @override
  void initState() {
    super.initState();
    _refundAmountController =
        TextEditingController(text: widget.initialRefundAmount);
    _loadPaymentMethods();
  }

  @override
  void dispose() {
    _refundAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentMethods() async {
    final provider = Provider.of<MasterDataProvider>(context, listen: false);
    if (provider.paymentMethods == null || provider.paymentMethods!.isEmpty) {
      await provider.fetchPaymentMethods();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

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
          maxWidth: screenWidth < 600 ? screenWidth - 48 : 520,
        ),
        child: BuildBoxShadowContainer(
          padding: const EdgeInsets.all(24),
          circleRadius: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Cancel Order",
                    style: buildCustomStyle(
                      FontWeightManager.semiBold,
                      FontSize.s20,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "Select a payment method and refund amount for this order.",
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s14,
                  0.27,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Consumer<MasterDataProvider>(
                      builder: (context, provider, child) {
                        final methods = provider.paymentMethods ?? [];
                        if (methods.isEmpty) {
                          return const Text("No payment methods available");
                        }
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              if (widget.initialRefundAmount.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  "Original total: ${widget.initialRefundAmount}",
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0.27,
                    ColorManager.textColor.withOpacity(0.7),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Delivery Charge Refundable",
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s14,
                            0.27,
                            ColorManager.textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Turn off to exclude the delivery charge from the refund.",
                          style: buildCustomStyle(
                            FontWeightManager.regular,
                            FontSize.s12,
                            0.27,
                            ColorManager.textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        "Close",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.27,
                          Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final refundAmount =
                            _refundAmountController.text.trim();
                        final parsedRefundAmount =
                            double.tryParse(refundAmount.replaceAll(',', ''));

                        if (_selectedPaymentMethodId == null) {
                          showScaffoldError(
                            context: context,
                            message: "Please select a payment method",
                          );
                          return;
                        }

                        if (refundAmount.isEmpty ||
                            parsedRefundAmount == null) {
                          showScaffoldError(
                            context: context,
                            message: "Please enter a valid refund amount",
                          );
                          return;
                        }

                        if (parsedRefundAmount <= 0) {
                          showScaffoldError(
                            context: context,
                            message: "Refund amount must be greater than 0",
                          );
                          return;
                        }

                        if (_originalTotal != null &&
                            parsedRefundAmount > _originalTotal!) {
                          showScaffoldError(
                            context: context,
                            message:
                                "Refund amount cannot exceed the original total",
                          );
                          return;
                        }

                        Navigator.of(context).pop();
                        widget.onConfirm(
                          _selectedPaymentMethodId!,
                          refundAmount,
                          _deliveryChargeRefundable,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPaymentMethodId != null
                            ? ColorManager.kPrimaryColor
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Confirm",
                        style: buildCustomStyle(
                          FontWeightManager.semiBold,
                          FontSize.s14,
                          0.27,
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
