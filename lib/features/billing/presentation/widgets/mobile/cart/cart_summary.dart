import 'package:flutter/material.dart';

class CartSummary extends StatelessWidget {
  const CartSummary({
    super.key,
    required this.subtotal,
    required this.tax,
    required this.total,
  });

  final double subtotal;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryRow(
          label: 'Subtotal',
          value: 'SAR ${subtotal.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 14),
        _SummaryRow(
          label: 'Tax (VAT 15%)',
          value: 'SAR ${tax.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 14),
        Divider(height: 1, color: Colors.grey.shade200),
        const SizedBox(height: 16),
        _SummaryRow(
          label: 'Total Payable',
          value: 'SAR ${total.toStringAsFixed(2)}',
          isEmphasized: true,
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isEmphasized = false,
  });

  final String label;
  final String value;
  final bool isEmphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: isEmphasized ? 18 : 13,
              fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w500,
              color: isEmphasized ? Colors.black87 : Colors.blueGrey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: isEmphasized ? 18 : 13,
            fontWeight: FontWeight.w700,
            color: isEmphasized ? const Color(0xFF1764C0) : Colors.black87,
          ),
        ),
      ],
    );
  }
}
