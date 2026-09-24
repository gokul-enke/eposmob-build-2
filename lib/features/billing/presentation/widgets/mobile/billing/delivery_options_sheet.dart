import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/billing/delivery_options_section.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/shared/mobile_sheet_header.dart';
import 'package:pos_machine/resources/color_manager.dart';

/// Bottom sheet wrapper around [DeliveryOptionsSection] for the mobile
/// Billing tab. Reuses the section as-is (it writes directly to providers),
/// so this sheet only needs to present it and offer a "Done" affordance.
Future<void> showDeliveryOptionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => const _DeliveryOptionsSheet(),
  );
}

class _DeliveryOptionsSheet extends StatelessWidget {
  const _DeliveryOptionsSheet();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MobileSheetHeader(
              title: 'billing.select_delivery_method'.tr,
              onClose: () => Navigator.pop(context),
            ),
            const Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: DeliveryOptionsSection(),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: ColorManager.kPrimaryColor,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'billing.done'.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
