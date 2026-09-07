import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import 'package:pos_machine/features/billing/domain/billing_crash_guards.dart';
import 'package:pos_machine/features/billing/controllers/billing_mobile_ui_controller.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/models/delivery_method_registry.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/providers/customer_selection_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

class DeliveryOptionsSection extends StatefulWidget {
  const DeliveryOptionsSection({super.key});

  @override
  State<DeliveryOptionsSection> createState() => _DeliveryOptionsSectionState();
}

class _DeliveryOptionsSectionState extends State<DeliveryOptionsSection> {
  static const _deliveryController = BillingMobileDeliveryController();
  static const _settingsController = BillingMobileSettingsController();
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

  @override
  Widget build(BuildContext context) {
    final bp = Provider.of<BillingProvider>(context);
    final deliveryProvider = Provider.of<DeliveryMethodsProvider>(context);
    final appSettingsProvider = Provider.of<AppSettingsProvider>(context);
    final customerProvider = Provider.of<CustomerSelectionProvider>(context);
    final localProductProvider = Provider.of<LocalProductProvider>(context);
    final currency = appSettingsProvider.appSettings?.currency ?? '';
    final netTotal = localProductProvider.priceSummary?.netTotal ??
        localProductProvider.cartTotal;
    final freeDeliveryEnabled =
        appSettingsProvider.appSettings?.freeDeliveryEnabled ?? false;
    final freeDeliveryMinimumAmount = double.tryParse(
          appSettingsProvider.appSettings?.freeDeliveryMinimumAmount.trim() ??
              '',
        ) ??
        0.0;
    final askDeliveryDate =
        _settingsController.shouldShowDeliveryDateTime(
      appSettingsProvider.appSettings,
    );

    // Sync order address from provider if modified outside (e.g. order rehydration)
    if (_addressController.text != bp.orderAddress) {
      _addressController.text = bp.orderAddress;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!BillingCrashGuards.hasDeliveryMethods(
            deliveryProvider.deliveryMethods)) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              deliveryProvider.isLoading
                  ? 'delivery_form.loading'.tr
                  : 'delivery_form.empty'.tr,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ] else
        // List of delivery methods
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: deliveryProvider.deliveryMethods.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final method = deliveryProvider.deliveryMethods[index];
            final isSelected = _deliveryController.isSelected(method, bp);

            final feeLabel = _deliveryController.feeLabelForMethodInOrder(
              method: method,
              currency: currency,
              freeDeliveryEnabled: freeDeliveryEnabled,
              freeDeliveryMinimumAmount: freeDeliveryMinimumAmount,
              netTotal: netTotal,
              deliveryMethods: deliveryProvider.deliveryMethods,
            );

            return InkWell(
              onTap: () => _deliveryController.selectMethod(bp, method),
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
                      _deliveryController.iconForMethod(method.name),
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
                        feeLabel,
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
          Text(
            'delivery_form.label_car_number'.tr,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: bp.carNumberController,
            decoration: InputDecoration(
              hintText: 'delivery_form.hint_car_number'.tr,
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

        // Optional door-delivery address fields
        if (DeliveryMethodRegistry.requiresAddress(bp.deliveryMethod)) ...[
          const SizedBox(height: 16),
          // Customer Address suggestions if selected
          if (customerProvider.hasSelectedCustomer &&
              customerProvider.selectedCustomer?.addresses != null &&
              customerProvider.selectedCustomer!.addresses!.isNotEmpty) ...[
            Text(
              'delivery_form.label_choose_address'.tr,
              style: const TextStyle(
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
                final fullAddress = _deliveryController.formatAddress(address);
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
          Text(
            'delivery_form.label_address'.tr,
            style: const TextStyle(
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
              hintText: 'delivery_form.hint_address'.tr,
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

        if (askDeliveryDate) ...[
          const SizedBox(height: 16),
          Text(
            'delivery_form.label_delivery_date'.tr,
            key: const Key('delivery_date_label'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          CalendarPickerTableCell(
            initialDate: bp.deliveryDate,
            onDateSelected: (date) => bp.setDeliveryDate(date),
          ),
          const SizedBox(height: 12),
          Text(
            'delivery_form.label_delivery_time'.tr,
            key: const Key('delivery_time_label'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TimePickerTableCell(
            initialTime: _deliveryController.parseDeliveryTime(bp.deliveryTime),
            onTimeSelected: (time) =>
                bp.setDeliveryTime(_deliveryController.formatDeliveryTime(time)),
          ),
        ],

        // Divider
        const Divider(height: 32, thickness: 1, color: Color(0xFFF1F5F9)),

        // Comment section
        Text(
          'delivery_form.label_comment'.tr,
          style: const TextStyle(
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
            hintText: 'delivery_form.hint_comment'.tr,
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
