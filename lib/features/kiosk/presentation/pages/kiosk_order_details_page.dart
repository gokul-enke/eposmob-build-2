import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/models/kiosk_order_draft.dart';
import 'package:pos_machine/features/kiosk/presentation/pages/kiosk_payment_page.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_flow_scaffold.dart';
import 'package:pos_machine/helpers/amount_helper.dart';
import 'package:pos_machine/models/delivery_method.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class KioskOrderDetailsPage extends StatefulWidget {
  final List<LocalCartItem> items;
  final String currency;

  const KioskOrderDetailsPage({
    super.key,
    required this.items,
    required this.currency,
  });

  @override
  State<KioskOrderDetailsPage> createState() => _KioskOrderDetailsPageState();
}

class _KioskOrderDetailsPageState extends State<KioskOrderDetailsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _vehicleController = TextEditingController();
  DeliveryMethod? _selectedMethod;
  bool _showCustomerDetails = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  void _selectInitialMethod(List<DeliveryMethod> methods) {
    if (_selectedMethod != null || methods.isEmpty) return;
    _selectedMethod = methods.first;
  }

  void _continue() {
    final selectedMethod = _selectedMethod;
    if (selectedMethod == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KioskPaymentPage(
          items: widget.items,
          currency: widget.currency,
          deliveryMethod: selectedMethod,
          customerName: _nameController.text.trim(),
          customerPhone: _phoneController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeliveryMethodsProvider>();
    final methods = provider.deliveryMethods
        .where((method) => method.enabled)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _selectInitialMethod(methods);
    final draft = KioskOrderDraft.fromCartItems(widget.items);

    return KioskFlowScaffold(
      title: 'Order details',
      stepLabel: 'Step 2 of 3',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;
          final padding = constraints.maxWidth < 600 ? 14.0 : 22.0;
          final details = _DetailsForm(
            methods: methods,
            loading: provider.isLoading,
            selectedMethod: _selectedMethod,
            onMethodSelected: (method) {
              setState(() => _selectedMethod = method);
            },
            showCustomerDetails: _showCustomerDetails,
            onCustomerDetailsChanged: (value) {
              setState(() => _showCustomerDetails = value);
            },
            nameController: _nameController,
            phoneController: _phoneController,
            addressController: _addressController,
            vehicleController: _vehicleController,
          );
          final summary = _DetailsSummary(
            itemCount: draft.itemCount,
            total: draft.total,
            currency: widget.currency,
            method: _selectedMethod,
            onContinue: _selectedMethod == null ? null : _continue,
          );

          if (wide) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SingleChildScrollView(child: details)),
                  const SizedBox(width: 20),
                  SizedBox(width: 360, child: summary),
                ],
              ),
            );
          }
          return ListView(
            padding: EdgeInsets.all(padding),
            children: [
              details,
              const SizedBox(height: 16),
              summary,
            ],
          );
        },
      ),
    );
  }
}

class _DetailsForm extends StatelessWidget {
  final List<DeliveryMethod> methods;
  final bool loading;
  final DeliveryMethod? selectedMethod;
  final ValueChanged<DeliveryMethod> onMethodSelected;
  final bool showCustomerDetails;
  final ValueChanged<bool> onCustomerDetailsChanged;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController addressController;
  final TextEditingController vehicleController;

  const _DetailsForm({
    required this.methods,
    required this.loading,
    required this.selectedMethod,
    required this.onMethodSelected,
    required this.showCustomerDetails,
    required this.onCustomerDetailsChanged,
    required this.nameController,
    required this.phoneController,
    required this.addressController,
    required this.vehicleController,
  });

  @override
  Widget build(BuildContext context) {
    return KioskSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KioskSectionTitle(
            'How would you like to receive your order?',
            subtitle: 'Choose from the options available at this store',
          ),
          const SizedBox(height: 18),
          if (loading && methods.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (methods.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFFB7791F)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No delivery methods are configured for this store.',
                      style: TextStyle(color: ColorManager.kTitleTextColor),
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth < 620
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: methods.map((method) {
                    return SizedBox(
                      width: width,
                      child: _DeliveryMethodTile(
                        method: method,
                        selected: selectedMethod?.id == method.id,
                        onTap: () => onMethodSelected(method),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 28),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: showCustomerDetails,
            onChanged: onCustomerDetailsChanged,
            activeTrackColor: ColorManager.kPrimaryColor,
            title: const Text(
              'Add contact details',
              style: TextStyle(
                color: ColorManager.kTitleTextColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'Optional — useful for order updates and receipts',
            ),
          ),
          if (showCustomerDetails) ...[
            const SizedBox(height: 14),
            _KioskTextField(
              controller: nameController,
              label: 'Name (optional)',
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _KioskTextField(
              controller: phoneController,
              label: 'Phone number (optional)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
          ],
          if (selectedMethod?.requiresAddress == true) ...[
            const SizedBox(height: 12),
            _KioskTextField(
              controller: addressController,
              label: 'Delivery address',
              icon: Icons.location_on_outlined,
              maxLines: 3,
            ),
          ],
          if (selectedMethod?.requiresCarNumber == true) ...[
            const SizedBox(height: 12),
            _KioskTextField(
              controller: vehicleController,
              label: 'Vehicle number',
              icon: Icons.directions_car_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

class _DeliveryMethodTile extends StatelessWidget {
  final DeliveryMethod method;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ColorManager.kPrimaryWithOpacity10
          : const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? ColorManager.kPrimaryColor
                  : const Color(0xFFE2E7F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _deliveryIcon(method.kind),
                  color: ColorManager.kPrimaryColor,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ColorManager.kTitleTextColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      method.basePrice == null || method.basePrice == 0
                          ? 'No extra charge'
                          : 'Delivery charge applies',
                      style: const TextStyle(color: ColorManager.kTextColor),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? ColorManager.kPrimaryColor
                    : ColorManager.kGreyColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KioskTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;

  const _KioskTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _DetailsSummary extends StatelessWidget {
  final int itemCount;
  final double total;
  final String currency;
  final DeliveryMethod? method;
  final VoidCallback? onContinue;

  const _DetailsSummary({
    required this.itemCount,
    required this.total,
    required this.currency,
    required this.method,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final deliveryCharge = method?.basePrice ?? 0;
    return KioskSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KioskSectionTitle('Your order'),
          const SizedBox(height: 20),
          _SummaryRow(label: 'Items', value: '$itemCount'),
          const SizedBox(height: 11),
          _SummaryRow(
            label: 'Order type',
            value: method?.label ?? 'Select one',
          ),
          if (deliveryCharge > 0) ...[
            const SizedBox(height: 11),
            _SummaryRow(
              label: 'Delivery',
              value: _money(currency, deliveryCharge),
            ),
          ],
          const Divider(height: 32),
          _SummaryRow(
            label: 'Payable total',
            value: _money(currency, total + deliveryCharge),
            emphasized: true,
          ),
          const SizedBox(height: 24),
          KioskPrimaryButton(
            label: 'Continue to payment',
            icon: Icons.arrow_forward_rounded,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: emphasized
                  ? ColorManager.kTitleTextColor
                  : ColorManager.kTextColor,
              fontSize: emphasized ? 18 : 15,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: emphasized ? 20 : 15,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

IconData _deliveryIcon(DeliveryKind kind) {
  switch (kind) {
    case DeliveryKind.storeTakeaway:
      return Icons.shopping_bag_outlined;
    case DeliveryKind.doorDelivery:
      return Icons.delivery_dining_rounded;
    case DeliveryKind.carDelivery:
      return Icons.directions_car_outlined;
    case DeliveryKind.thirdPartyLogistics:
      return Icons.local_shipping_outlined;
    case DeliveryKind.other:
      return Icons.storefront_outlined;
  }
}

String _money(String currency, num value) {
  final prefix = currency.trim().isEmpty ? '' : '${currency.trim()} ';
  return '$prefix${AmountHelper.formatAmount(value)}';
}
