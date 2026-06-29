import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';

class DeliveryOptionsSection extends StatefulWidget {
  const DeliveryOptionsSection({super.key});

  @override
  State<DeliveryOptionsSection> createState() => _DeliveryOptionsSectionState();
}

class _DeliveryOptionsSectionState extends State<DeliveryOptionsSection> {
  late TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    final bp = Provider.of<BillingProvider>(context, listen: false);
    _addressController = TextEditingController(text: bp.orderAddress);
    _addressController.addListener(() {
      bp.setOrderAddress(_addressController.text);
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  IconData _getDeliveryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('dine')) return Icons.restaurant;
    if (lower.contains('toyou')) return Icons.local_shipping;
    if (lower.contains('door')) return Icons.doorbell_outlined;
    if (lower.contains('store') || lower.contains('takeaway')) {
      return Icons.store;
    }
    if (lower.contains('car')) return Icons.directions_car;
    if (lower.contains('third') || lower.contains('logistics')) {
      return Icons.hub;
    }
    if (lower.contains('hunger')) return Icons.motorcycle;
    return Icons.local_shipping;
  }

  @override
  Widget build(BuildContext context) {
    final bp = Provider.of<BillingProvider>(context);
    final deliveryProvider = Provider.of<DeliveryMethodsProvider>(context);
    final appSettingsProvider = Provider.of<AppSettingsProvider>(context);
    final customerProvider = Provider.of<CustomerSelectionProvider>(context);
    final currency = appSettingsProvider.appSettings?.currency ?? 'SAR';

    // Sync order address from provider if modified outside (e.g. order rehydration)
    if (_addressController.text != bp.orderAddress) {
      _addressController.text = bp.orderAddress;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // List of delivery methods
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: deliveryProvider.deliveryMethods.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final method = deliveryProvider.deliveryMethods[index];
            final isSelected = bp.deliveryMethod == method.name ||
                (bp.deliveryMethod.isEmpty &&
                    method.name == 'Store Takeaway');

            final double price = method.basePrice ?? 0.0;
            final isFree = price == 0.0;

            return InkWell(
              onTap: () {
                bp.setDeliveryMethod(method.name, method.id);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : Colors.grey.shade200,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getDeliveryIcon(method.name),
                      color: isSelected
                          ? const Color(0xFF0066CC)
                          : Colors.grey.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        method.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xFF0066CC)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    // Fee chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7), // Light green
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isFree
                            ? 'Free'
                            : '($currency ${price.toStringAsFixed(2)})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF15803D), // Dark green
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Optional Car Delivery fields
        if (bp.requiresCarNumber()) ...[
          const SizedBox(height: 16),
          const Text(
            'Car Number:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: bp.carNumberController,
            decoration: InputDecoration(
              hintText: 'Enter car number...',
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
                bp.carNumberController,
                replaceOnFirstInput: true,
              );
            },
          ),
        ],

        // Optional Door Delivery Address fields
        if (bp.deliveryMethod == "Door Delivery") ...[
          const SizedBox(height: 16),
          // Customer Address suggestions if selected
          if (customerProvider.hasSelectedCustomer &&
              customerProvider.selectedCustomer!.addresses != null &&
              customerProvider.selectedCustomer!.addresses!.isNotEmpty) ...[
            const Text(
              'Choose an address:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: customerProvider.selectedCustomer!.addresses!
                  .map((Address address) {
                final fullAddress = "${address.address}, ${address.city}";
                return InkWell(
                  onTap: () {
                    setState(() {
                      _addressController.text = fullAddress;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      fullAddress,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Address:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _addressController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Enter delivery address...',
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
                _addressController,
                replaceOnFirstInput: true,
              );
            },
          ),
        ],

        // Divider
        const Divider(height: 32, thickness: 1, color: Color(0xFFF1F5F9)),

        // Comment section
        const Text(
          'Comment:',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: bp.commentController,
          maxLines: 3,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'Add special instructions or comments...',
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
              bp.commentController,
              replaceOnFirstInput: true,
            );
          },
        ),
      ],
    );
  }
}
