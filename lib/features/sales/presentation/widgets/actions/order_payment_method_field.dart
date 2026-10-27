import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/sales_payment_codes.dart';
import 'package:pos_machine/models/master_data.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:provider/provider.dart';

/// Payment method dropdown of the order action forms (Refund Payment Method,
/// Update Payment Status): the company's payment methods from master data,
/// loaded on first use. The value is the method's master-data id, which the
/// order APIs take as `payment_method`.
class OrderPaymentMethodField extends StatefulWidget {
  const OrderPaymentMethodField(
      {super.key,
      required this.value,
      required this.onChanged,
      this.initialCode});
  final String? value;
  final ValueChanged<String?> onChanged;

  /// The order's own method (code like `CASH`, id or label), picked once the
  /// methods are known while nothing is selected yet.
  final String? initialCode;

  @override
  State<OrderPaymentMethodField> createState() =>
      _OrderPaymentMethodFieldState();
}

class _OrderPaymentMethodFieldState extends State<OrderPaymentMethodField> {
  late final MasterDataProvider _master;
  late bool _isLoadingMethods;

  @override
  void initState() {
    super.initState();
    _master = context.read<MasterDataProvider>();
    _isLoadingMethods = _master.paymentMethods?.isEmpty ?? true;
    // After the first frame: picking a method updates the parent form.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPaymentMethods());
  }

  Future<void> _loadPaymentMethods() async {
    if (_master.paymentMethods == null || _master.paymentMethods!.isEmpty) {
      await _master.fetchPaymentMethods();
    }
    if (!mounted) return;
    setState(() {
      _isLoadingMethods = false;
    });
    final raw = widget.initialCode?.trim();
    if (widget.value != null || raw == null || raw.isEmpty) return;
    // Orders may hold the method's code, id or label; resolve to the code.
    final code = (SalesPaymentCodes.resolve(raw) ?? raw).toLowerCase();
    for (final method in _master.paymentMethods ?? const <MasterDataValue>[]) {
      if (method.value.toLowerCase() == code || method.id.toString() == raw) {
        widget.onChanged(method.id.toString());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => _isLoadingMethods
      ? const Center(
          child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ))
      : Consumer<MasterDataProvider>(
          builder: (context, provider, child) {
            final methods = provider.paymentMethods ?? [];
            // A value the loaded list no longer has would break the dropdown.
            final value = methods.any((m) => m.id.toString() == widget.value)
                ? widget.value
                : null;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text('change_order_status.hint_payment_method'.tr),
                  value: value,
                  items: methods.map((MasterDataValue method) {
                    return DropdownMenuItem<String>(
                      value: method.id.toString(),
                      child: Text(method.value),
                    );
                  }).toList(),
                  onChanged: widget.onChanged,
                ),
              ),
            );
          },
        );
}
