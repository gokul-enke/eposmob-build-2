import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:provider/provider.dart';

class CancelOrderModal extends StatefulWidget {
  final Function(String paymentMethodId, bool deliveryChargeRefundable)
      onConfirm;

  const CancelOrderModal({
    super.key,
    required this.onConfirm,
  });

  @override
  State<CancelOrderModal> createState() => _CancelOrderModalState();
}

class _CancelOrderModalState extends State<CancelOrderModal> {
  String? _selectedPaymentMethodId;
  bool _isLoading = true;
  bool _deliveryChargeRefundable = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
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
              "Select a payment method to refund this order.",
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
                      if (_selectedPaymentMethodId != null) {
                        Navigator.of(context).pop();
                        widget.onConfirm(
                          _selectedPaymentMethodId!,
                          _deliveryChargeRefundable,
                        );
                      } else {
                        showScaffoldError(
                          context: context,
                          message: "Please select a payment method",
                        );
                      }
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
    );
  }
}
