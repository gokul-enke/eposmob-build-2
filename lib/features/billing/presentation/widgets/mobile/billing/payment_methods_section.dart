import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/domain/billing_debug_log.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/models/payment_method.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/pine_labs_section.dart';

// To-customer-credit UX lives in [_ToCustomerCreditSection] below.

class PaymentMethodsSection extends StatefulWidget {
  const PaymentMethodsSection({super.key});

  @override
  State<PaymentMethodsSection> createState() => _PaymentMethodsSectionState();
}

class _PaymentMethodsSectionState extends State<PaymentMethodsSection> {
  static const _controller = BillingMobilePaymentController();
  static const _customerController = BillingMobileCustomerController();
  static const _settingsController = BillingMobileSettingsController();
  bool _isLoadingPaymentMethods = false;
  List<PaymentMethod> _paymentMethods = [];

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    final masterDataProvider =
        Provider.of<MasterDataProvider>(context, listen: false);
    final cachedModels = masterDataProvider.paymentMethodModels;
    if (cachedModels != null && cachedModels.isNotEmpty) {
      _applyPaymentMethods(masterDataProvider.enabledSortedPaymentMethods);
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingPaymentMethods = true;
      });
    }

    try {
      await masterDataProvider.fetchPaymentMethods();
      if (mounted) {
        _applyPaymentMethods(masterDataProvider.enabledSortedPaymentMethods);
      }
    } catch (e) {
      billingDebugLog('Error loading payment methods: $e');
      // Degrade gracefully to the minimal default (single CASH) so billing is
      // never blocked when both API and cache are empty.
      if (mounted) {
        _applyPaymentMethods(masterDataProvider.enabledSortedPaymentMethods);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPaymentMethods = false;
        });
      }
    }
  }

  void _applyPaymentMethods(List<PaymentMethod> methods) {
    if (mounted) {
      setState(() {
        _paymentMethods = methods;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final bp = Provider.of<BillingProvider>(context, listen: false);
        _controller.syncPaymentMethodIdsFromModels(bp, methods);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingPaymentMethods && _paymentMethods.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final showPineLabPayment = _settingsController.shouldShowPineLabPayment(
      context.watch<AppSettingsProvider>().appSettings,
    );

    return Selector<BillingProvider, _PaymentMethodsSnapshot>(
      selector: (_, bp) => _PaymentMethodsSnapshot.from(bp),
      builder: (context, snapshot, _) {
        final bp = Provider.of<BillingProvider>(context, listen: false);
        final items = _controller.paymentItems(bp, _paymentMethods);

        if (snapshot.totalOrderAmount > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _controller.syncPaymentAutofillIfNeeded(bp);
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (snapshot.totalOrderAmount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: Text('billing.exact_cash'.tr),
                      onPressed: () {
                        _controller.fillExactCash(bp);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: Text('billing.clear_payments'.tr),
                      onPressed: () {
                        _controller.clearAllCollectedPayments(bp);
                      },
                    ),
                  ],
                ),
              ),
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

                if (item.behavior == PaymentBehavior.credit &&
                    isSelected &&
                    snapshot.totalOrderAmount > 0 &&
                    !snapshot.toCustomerCreditEnabled) {
                  final expectedDebit =
                      _controller.remainingPayable(bp).toStringAsFixed(2);
                  if (controller.text != expectedDebit) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _controller.syncDebitAmount(bp);
                    });
                  }
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
                                _controller.iconForItem(item),
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
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey.shade300),
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

            _ToCustomerCreditSection(
              controller: _controller,
              customerController: _customerController,
            ),
            const SizedBox(height: 16),

            // Transaction Reference Input
            const Text(
              'Transaction Reference',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
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
            if (showPineLabPayment) ...[
              const SizedBox(height: 16),
              const PineLabsSection(),
            ],
          ],
        );
      },
    );
  }
}

@immutable
class _PaymentMethodsSnapshot {
  const _PaymentMethodsSnapshot({
    required this.totalOrderAmount,
    required this.isCashSelected,
    required this.isCardSelected,
    required this.isUpiSelected,
    required this.isCodSelected,
    required this.isDebitSelected,
    required this.toCustomerCreditEnabled,
    required this.selectedCustomerId,
    required this.selectedExtraMethodIds,
  });

  factory _PaymentMethodsSnapshot.from(BillingProvider bp) {
    return _PaymentMethodsSnapshot(
      totalOrderAmount: bp.totalOrderAmount,
      isCashSelected: bp.isCashSelected == true,
      isCardSelected: bp.isCardSelected == true,
      isUpiSelected: bp.isUpiSelected == true,
      isCodSelected: bp.isCodSelected == true,
      isDebitSelected: bp.isDebitSelected == true,
      toCustomerCreditEnabled: bp.toCustomerCreditEnabled == true,
      selectedCustomerId: bp.selectedCustomer?.id,
      selectedExtraMethodIds: Set<String>.from(bp.selectedExtraMethodIds),
    );
  }

  final double totalOrderAmount;
  final bool isCashSelected;
  final bool isCardSelected;
  final bool isUpiSelected;
  final bool isCodSelected;
  final bool isDebitSelected;
  final bool toCustomerCreditEnabled;
  final int? selectedCustomerId;
  final Set<String> selectedExtraMethodIds;

  @override
  bool operator ==(Object other) {
    return other is _PaymentMethodsSnapshot &&
        other.totalOrderAmount == totalOrderAmount &&
        other.isCashSelected == isCashSelected &&
        other.isCardSelected == isCardSelected &&
        other.isUpiSelected == isUpiSelected &&
        other.isCodSelected == isCodSelected &&
        other.isDebitSelected == isDebitSelected &&
        other.toCustomerCreditEnabled == toCustomerCreditEnabled &&
        other.selectedCustomerId == selectedCustomerId &&
        setEquals(other.selectedExtraMethodIds, selectedExtraMethodIds);
  }

  @override
  int get hashCode => Object.hash(
        totalOrderAmount,
        isCashSelected,
        isCardSelected,
        isUpiSelected,
        isCodSelected,
        isDebitSelected,
        toCustomerCreditEnabled,
        selectedCustomerId,
        Object.hashAllUnordered(selectedExtraMethodIds),
      );
}

class _ToCustomerCreditSection extends StatelessWidget {
  const _ToCustomerCreditSection({
    required this.controller,
    required this.customerController,
  });

  final BillingMobilePaymentController controller;
  final BillingMobileCustomerController customerController;

  @override
  Widget build(BuildContext context) {
    final customerSelection =
        Provider.of<CustomerSelectionProvider>(context, listen: true);
    final appSettings =
        Provider.of<AppSettingsProvider>(context, listen: true).appSettings;
    final defaultCustomerPhone =
        appSettings?.autoAssignDefaultCustomerPhone ?? '';
    final currency = appSettings?.currency ?? '';

    return Selector<BillingProvider, _ToCustomerCreditSnapshot>(
      selector: (_, bp) => _ToCustomerCreditSnapshot.from(bp),
      builder: (context, snapshot, _) {
        final bp = Provider.of<BillingProvider>(context, listen: false);
        final customer = customerSelection.selectedCustomer;

        if (!controller.shouldShowToCustomerCreditSection(
          customer: customer,
          customerSelectionProvider: customerSelection,
          defaultCustomerPhone: defaultCustomerPhone,
        )) {
          return const SizedBox.shrink();
        }

        final balanceDisplay = customerController.balanceDisplay(
          balance: customer?.balance ?? 0.0,
          currency: currency,
        );
        final maxAllowed = controller.maxToCustomerCreditAmount(bp);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: snapshot.toCustomerCreditEnabled
                  ? const Color(0xFF3B82F6)
                  : Colors.grey.shade200,
              width: snapshot.toCustomerCreditEnabled ? 1.5 : 1,
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: snapshot.toCustomerCreditEnabled
                        ? const Color(0xFF0066CC)
                        : Colors.grey.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'To Customer Credit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0066CC),
                      ),
                    ),
                  ),
                  Switch(
                    value: snapshot.toCustomerCreditEnabled,
                    activeColor: const Color(0xFF3B82F6),
                    onChanged: (value) {
                      controller.toggleToCustomerCredit(bp, value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    balanceDisplay.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: balanceDisplay.color,
                    ),
                  ),
                  Text(
                    balanceDisplay.amountText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: balanceDisplay.color,
                    ),
                  ),
                ],
              ),
              if (snapshot.toCustomerCreditEnabled) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: bp.debitAmountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0066CC),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter amount to add as customer credit',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(
                        color: ColorManager.kPrimaryColor,
                        width: 1.5,
                      ),
                    ),
                    helperText: maxAllowed > 0
                        ? 'Max: $currency ${maxAllowed.toStringAsFixed(2)}'
                        : 'No excess payment available',
                    helperStyle: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  onTap: () {
                    Provider.of<KeyboardProvider>(context, listen: false).show(
                      'number',
                      bp.debitAmountController,
                      replaceOnFirstInput: true,
                    );
                  },
                  onChanged: (value) {
                    controller.onToCustomerCreditAmountChanged(bp, value);
                  },
                  onEditingComplete: () {
                    controller.clampToCustomerCreditAmount(bp);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

@immutable
class _ToCustomerCreditSnapshot {
  const _ToCustomerCreditSnapshot({
    required this.toCustomerCreditEnabled,
    required this.totalPaidAmount,
    required this.totalOrderAmount,
    required this.debitAmountText,
    required this.customerBalance,
  });

  factory _ToCustomerCreditSnapshot.from(BillingProvider bp) {
    return _ToCustomerCreditSnapshot(
      toCustomerCreditEnabled: bp.toCustomerCreditEnabled,
      totalPaidAmount: bp.totalPaidAmount,
      totalOrderAmount: bp.totalOrderAmount,
      debitAmountText: bp.debitAmountController.text,
      customerBalance: bp.selectedCustomer?.balance ?? 0.0,
    );
  }

  final bool toCustomerCreditEnabled;
  final double totalPaidAmount;
  final double totalOrderAmount;
  final String debitAmountText;
  final double customerBalance;

  @override
  bool operator ==(Object other) {
    return other is _ToCustomerCreditSnapshot &&
        other.toCustomerCreditEnabled == toCustomerCreditEnabled &&
        other.totalPaidAmount == totalPaidAmount &&
        other.totalOrderAmount == totalOrderAmount &&
        other.debitAmountText == debitAmountText &&
        other.customerBalance == customerBalance;
  }

  @override
  int get hashCode => Object.hash(
        toCustomerCreditEnabled,
        totalPaidAmount,
        totalOrderAmount,
        debitAmountText,
        customerBalance,
      );
}
