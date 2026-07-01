import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/domain/billing_crash_guards.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';

class CustomerSummaryCard extends StatelessWidget {
  final CustomerListModelData? customer;
  final MobileCustomerBalanceDisplay? balanceDisplay;
  /// When non-null and non-empty, shows a B2B/B2C badge (gated by parent via
  /// [companyB2BEnabled], matching desktop billing header logic).
  final String? customerType;
  final VoidCallback? onClear;
  final VoidCallback? onTap;

  const CustomerSummaryCard({
    super.key,
    this.customer,
    this.balanceDisplay,
    this.customerType,
    this.onClear,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String? displayCustomerType = customerType?.trim().isEmpty == true
        ? null
        : customerType?.trim().toUpperCase();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: ColorManager.kPrimaryColor,
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Customer',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          BillingCrashGuards.customerDisplayName(customer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0066CC),
                          ),
                        ),
                      ),
                      if (displayCustomerType != null) ...[
                        const SizedBox(width: 8),
                        _CustomerTypeBadge(label: displayCustomerType),
                      ],
                    ],
                  ),
                  if (BillingCrashGuards.customerDisplayPhone(customer) !=
                      null) ...[
                    const SizedBox(height: 2),
                    Text(
                      BillingCrashGuards.customerDisplayPhone(customer)!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  if (balanceDisplay != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          '${balanceDisplay!.label}: ',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            balanceDisplay!.amountText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: balanceDisplay!.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// B2B/B2C pill — styling aligned with desktop [HeaderBar] customer badge.
class _CustomerTypeBadge extends StatelessWidget {
  final String label;

  const _CustomerTypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isB2B = label == 'B2B';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isB2B ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isB2B ? Colors.green.shade300 : Colors.blue.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isB2B ? Colors.green.shade700 : Colors.blue.shade700,
        ),
      ),
    );
  }
}
