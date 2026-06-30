import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/pine_labs_section.dart';

class PaymentMethodsSection extends StatefulWidget {
  const PaymentMethodsSection({super.key});

  @override
  State<PaymentMethodsSection> createState() => _PaymentMethodsSectionState();
}

class _PaymentMethodsSectionState extends State<PaymentMethodsSection> {
  static const _controller = BillingMobilePaymentController();
  bool _isLoadingPaymentMethods = false;
  List<MasterDataValue> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final cachedMethods = masterDataProvider.paymentMethods;
    if (cachedMethods != null && cachedMethods.isNotEmpty) {
      _assignPaymentMethodIds(cachedMethods);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingPaymentMethods = true;
      });
    }

    try {
      final methods = await masterDataProvider.fetchPaymentMethods();
      if (mounted && methods != null) {
        _assignPaymentMethodIds(methods);
      }
    } catch (e) {
      debugPrint('Error loading payment methods: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPaymentMethods = false;
        });
      }
    }
  }

  void _assignPaymentMethodIds(List<MasterDataValue> methods) {
    final sortedMethods = _controller.sortPaymentMethods(methods);
    final ids = _controller.paymentMethodIds(sortedMethods);

    if (mounted) {
      setState(() {
        _paymentMethods = sortedMethods;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bp = Provider.of<BillingProvider>(context, listen: false);
        bp.updatePaymentMethodIds(
          cashId: ids.cashId,
          cardId: ids.cardId,
          upiId: ids.upiId,
          codId: ids.codId,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bp = Provider.of<BillingProvider>(context);
    final items = _controller.paymentItems(bp, _paymentMethods);

    if (_isLoadingPaymentMethods && _paymentMethods.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // List of payment items
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = items[index];
            final name = item.name;
            final type = item.type;
            final controller = item.controller;
            final isSelected = item.selected;
            final readOnly = item.readOnly;

            if (!_controller.shouldShowItem(item, bp)) {
              return const SizedBox.shrink();
            }

            if (type == 'DEBIT' && isSelected && bp.totalOrderAmount > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _controller.syncDebitAmount(bp);
              });
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF3B82F6)
                      : Colors.grey.shade200,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => _controller.toggleMethod(
                  type,
                  bp,
                  methodId: item.methodId,
                  displayValue: item.type,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Icon + Name
                      Row(
                        children: [
                          Icon(
                            _controller.iconForType(type),
                            color: isSelected
                                ? const Color(0xFF0066CC)
                                : Colors.grey.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF0066CC)
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Amount input field
                      TextField(
                        controller: controller,
                        readOnly: readOnly,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF0066CC)
                              : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: readOnly
                              ? 'Auto-calculated'
                              : 'Enter $name amount',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : ColorManager.kPrimaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onTap: () {
                          _controller.selectMethodOnTap(item, bp);
                          if (!readOnly) {
                            Provider.of<KeyboardProvider>(context,
                                    listen: false)
                                .show(
                              'number',
                              controller,
                              replaceOnFirstInput: true,
                            );
                          }
                        },
                        onChanged: (value) =>
                            _controller.onAmountChanged(item, value, bp),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Transaction Reference Input
        const Text(
          'Transaction Reference',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: bp.transactionNumberController,
          decoration: InputDecoration(
            hintText: 'Enter transaction reference number',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: ColorManager.kPrimaryColor, width: 1.5),
            ),
          ),
          onTap: () {
            Provider.of<KeyboardProvider>(context, listen: false).show(
              'text',
              bp.transactionNumberController,
              replaceOnFirstInput: true,
            );
          },
        ),
        const SizedBox(height: 16),

        // Integration with PineLabs terminal (keep visual separation)
        const PineLabsSection(),
      ],
    );
  }
}
