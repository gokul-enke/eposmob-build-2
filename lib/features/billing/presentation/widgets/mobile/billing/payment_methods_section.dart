import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
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
  bool _isLoadingPaymentMethods = false;
  List<MasterDataValue> _paymentMethods = [];

  // Local payment IDs
  String? _cashPaymentMethodId;
  String? _cardPaymentMethodId;
  String? _upiPaymentMethodId;
  String? _codPaymentMethodId;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final masterDataProvider = Provider.of<MasterDataProvider>(context, listen: false);
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
    final sortedMethods = List<MasterDataValue>.from(methods);
    sortedMethods.sort((a, b) {
      if (a.value.toUpperCase() == 'CASH') return -1;
      if (b.value.toUpperCase() == 'CASH') return 1;
      return a.value.compareTo(b.value);
    });

    if (mounted) {
      setState(() {
        _paymentMethods = sortedMethods;
      });
    }

    for (final method in sortedMethods) {
      final value = method.value.toUpperCase();
      if (value == 'CASH') {
        _cashPaymentMethodId = method.id.toString();
      } else if (value == 'CARD') {
        _cardPaymentMethodId = method.id.toString();
      } else if (value == 'UPI') {
        _upiPaymentMethodId = method.id.toString();
      } else if (value == 'COD') {
        _codPaymentMethodId = method.id.toString();
      }
    }

    // Proactively send payment method IDs to provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bp = Provider.of<BillingProvider>(context, listen: false);
        bp.updatePaymentMethodIds(
          cashId: _cashPaymentMethodId,
          cardId: _cardPaymentMethodId,
          upiId: _upiPaymentMethodId,
          codId: _codPaymentMethodId,
        );
      }
    });
  }

  IconData _getPaymentIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('cash')) return Icons.money;
    if (lower.contains('card')) return Icons.credit_card;
    if (lower.contains('upi')) return Icons.qr_code;
    if (lower.contains('cod')) return Icons.local_shipping;
    if (lower.contains('debit') || lower.contains('credit')) return Icons.account_balance_wallet;
    return Icons.payment;
  }

  double _getRemainingPayable(BillingProvider bp) {
    double cashAmount = double.tryParse(bp.cashAmountController.text) ?? 0.0;
    double cardAmount = double.tryParse(bp.cardAmountController.text) ?? 0.0;
    double upiAmount = double.tryParse(bp.upiAmountController.text) ?? 0.0;
    double codAmount = double.tryParse(bp.codAmountController.text) ?? 0.0;
    double totalCollected = cashAmount + cardAmount + upiAmount + codAmount;
    double remaining = bp.totalOrderAmount - totalCollected;
    return remaining > 0 ? remaining : 0.0;
  }

  void _toggleMethod(String type, BillingProvider bp) {
    final bool isSelected;
    final TextEditingController controller;

    switch (type.toUpperCase()) {
      case 'CASH':
        isSelected = bp.isCashSelected;
        controller = bp.cashAmountController;
        break;
      case 'CARD':
        isSelected = bp.isCardSelected;
        controller = bp.cardAmountController;
        break;
      case 'UPI':
        isSelected = bp.isUpiSelected;
        controller = bp.upiAmountController;
        break;
      case 'COD':
        isSelected = bp.isCodSelected;
        controller = bp.codAmountController;
        break;
      case 'DEBIT':
        isSelected = bp.isDebitSelected;
        controller = bp.debitAmountController;
        break;
      default:
        return;
    }

    if (isSelected) {
      bp.setPaymentMethod(type, false);
    } else {
      bp.setPaymentMethod(type, true);
      // Auto-fill remaining payable if amount is currently empty
      if (controller.text.isEmpty || double.tryParse(controller.text) == 0.0) {
        final remaining = _getRemainingPayable(bp);
        if (remaining > 0) {
          controller.text = remaining.toStringAsFixed(2);
          bp.calculateBalance();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = Provider.of<BillingProvider>(context);

    // Prepare list of payment items: CASH, CARD, UPI, COD, CREDIT (DEBIT)
    final List<Map<String, dynamic>> items = [
      {'name': 'Cash', 'type': 'CASH', 'controller': bp.cashAmountController, 'selected': bp.isCashSelected},
      {'name': 'Card', 'type': 'CARD', 'controller': bp.cardAmountController, 'selected': bp.isCardSelected},
      {'name': 'UPI', 'type': 'UPI', 'controller': bp.upiAmountController, 'selected': bp.isUpiSelected},
      {'name': 'COD', 'type': 'COD', 'controller': bp.codAmountController, 'selected': bp.isCodSelected},
      {'name': 'Credit', 'type': 'DEBIT', 'controller': bp.debitAmountController, 'selected': bp.isDebitSelected, 'readOnly': true},
    ];

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
            final String name = item['name'];
            final String type = item['type'];
            final TextEditingController controller = item['controller'];
            final bool isSelected = item['selected'];
            final bool readOnly = item['readOnly'] ?? false;

            // Credit logic: if selectedCustomer is null, hide Credit option
            if (type == 'DEBIT' && bp.selectedCustomer == null) {
              return const SizedBox.shrink();
            }

            // Sync debit amount with auto-calculated balance if DEBIT is selected
            if (type == 'DEBIT' && isSelected && bp.totalOrderAmount > 0) {
              final cashAmount = double.tryParse(bp.cashAmountController.text) ?? 0.0;
              final cardAmount = double.tryParse(bp.cardAmountController.text) ?? 0.0;
              final upiAmount = double.tryParse(bp.upiAmountController.text) ?? 0.0;
              final codAmount = double.tryParse(bp.codAmountController.text) ?? 0.0;
              final remaining = bp.totalOrderAmount - (cashAmount + cardAmount + upiAmount + codAmount);
              final autoDebit = remaining > 0 ? remaining : 0.0;
              if (controller.text != autoDebit.toStringAsFixed(2)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  controller.text = autoDebit.toStringAsFixed(2);
                  bp.calculateBalance();
                });
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? const Color(0xFF3B82F6) : Colors.grey.shade200,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: InkWell(
                onTap: () => _toggleMethod(type, bp),
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
                            _getPaymentIcon(type),
                            color: isSelected ? const Color(0xFF0066CC) : Colors.grey.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF0066CC) : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Amount input field
                      TextField(
                        controller: controller,
                        readOnly: readOnly,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF0066CC) : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: readOnly ? 'Auto-calculated' : 'Enter $name amount',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              color: isSelected ? const Color(0xFF3B82F6) : ColorManager.kPrimaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onTap: () {
                          // Select the method automatically when tapping input
                          if (!isSelected) {
                            bp.setPaymentMethod(type, true);
                          }
                          if (!readOnly) {
                            Provider.of<KeyboardProvider>(context, listen: false).show(
                              'number',
                              controller,
                              replaceOnFirstInput: true,
                            );
                          }
                        },
                        onChanged: (value) {
                          // Update payment selections & calculate balance on input changes
                          if (value.isNotEmpty && double.tryParse(value) != 0.0) {
                            if (!isSelected) bp.setPaymentMethod(type, true);
                          }
                          bp.calculateBalance();
                        },
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
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: bp.transactionNumberController,
          decoration: InputDecoration(
            hintText: 'Enter transaction reference number',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              borderSide: const BorderSide(color: ColorManager.kPrimaryColor, width: 1.5),
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
