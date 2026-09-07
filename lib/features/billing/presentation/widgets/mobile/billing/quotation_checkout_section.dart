import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/billing/domain/quotation_checkout.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';

/// Quotation date pickers and inline new-customer fields for mobile quotation
/// billing. Mirrors desktop checkout modal `_buildQuotationDatesPanel`.
class QuotationCheckoutSection extends StatefulWidget {
  final DateTime quotationDate;
  final DateTime expiryDate;
  final ValueChanged<DateTime> onQuotationDateChanged;
  final ValueChanged<DateTime> onExpiryDateChanged;
  final TextEditingController inlineNameController;
  final TextEditingController inlinePhoneController;
  final VoidCallback onInlineCustomerChanged;
  final VoidCallback? onSelectCustomer;

  const QuotationCheckoutSection({
    super.key,
    required this.quotationDate,
    required this.expiryDate,
    required this.onQuotationDateChanged,
    required this.onExpiryDateChanged,
    required this.inlineNameController,
    required this.inlinePhoneController,
    required this.onInlineCustomerChanged,
    this.onSelectCustomer,
  });

  @override
  State<QuotationCheckoutSection> createState() =>
      _QuotationCheckoutSectionState();
}

class _QuotationCheckoutSectionState extends State<QuotationCheckoutSection> {
  Future<void> _pickDate({
    required DateTime initialDate,
    required DateTime firstDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final effectiveInitial =
        initialDate.isBefore(firstDate) ? firstDate : initialDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: effectiveInitial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCustomer =
        Provider.of<CustomerSelectionProvider>(context).selectedCustomer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onSelectCustomer != null) ...[
            OutlinedButton.icon(
              onPressed: widget.onSelectCustomer,
              icon: const Icon(Icons.person_search, size: 18),
              label: Text('ui_chrome.select_saved_customer'.tr),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (selectedCustomer?.id != null) ...[
            Text(
              selectedCustomer!.name ?? 'Selected customer',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            if (selectedCustomer.phone?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                selectedCustomer.phone!.trim(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Or enter a new customer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _InlineField(
                  label: 'checkout_modal.label_customer_name'.tr,
                  controller: widget.inlineNameController,
                  hintText: 'checkout_modal.hint_customer_name'.tr,
                  onChanged: (_) => widget.onInlineCustomerChanged(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InlineField(
                  label: 'checkout_modal.label_customer_phone'.tr,
                  controller: widget.inlinePhoneController,
                  hintText: 'checkout_modal.hint_customer_phone'.tr,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => widget.onInlineCustomerChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'checkout_modal.label_quotation_date'.tr,
                  date: widget.quotationDate,
                  onTap: () => _pickDate(
                    initialDate: widget.quotationDate,
                    firstDate: DateTime(2020),
                    onSelected: (date) {
                      widget.onQuotationDateChanged(date);
                      if (widget.expiryDate.isBefore(date)) {
                        widget.onExpiryDateChanged(
                          QuotationCheckout.defaultExpiryFor(date),
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'checkout_modal.label_expiry_date'.tr,
                  date: widget.expiryDate,
                  onTap: () => _pickDate(
                    initialDate: widget.expiryDate.isBefore(widget.quotationDate)
                        ? QuotationCheckout.defaultExpiryFor(
                            widget.quotationDate)
                        : widget.expiryDate,
                    firstDate: widget.quotationDate,
                    onSelected: widget.onExpiryDateChanged,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _InlineField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDDE7F3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDDE7F3)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 4),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDDE7F3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      MaterialLocalizations.of(context).formatMediumDate(date),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
