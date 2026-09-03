import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/screens/login/store_selection_screen.dart';
import 'package:provider/provider.dart';

class StoreSwitcher extends StatelessWidget {
  const StoreSwitcher({super.key});

  void _navigateToStoreSelection(BuildContext context) {
    final storeSession = context.read<StoreSessionProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StoreSelectionScreen(
          stores: storeSession.availableStores,
          isFromLogin: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StoreSessionProvider>(
      builder: (context, storeSession, _) {
        final stores = storeSession.availableStores;
        final isLoading = storeSession.isBootstrapping;
        final status = storeSession.statusMessage;

        if (stores.isEmpty) {
          return Text(
            'common.no_stores_assigned'.tr,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.16,
              ColorManager.textColor,
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'common.active_store'.tr,
                  style: buildCustomStyle(
                    FontWeightManager.semiBold,
                    FontSize.s12,
                    0.16,
                    ColorManager.textColor,
                  ),
                ),
                if (!isLoading)
                  InkWell(
                    onTap: () => _navigateToStoreSelection(context),
                    child: const Icon(
                      Icons.swap_horiz,
                      size: 20,
                      color: ColorManager.kPrimaryColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: isLoading
                  ? null
                  : () => _navigateToStoreSelection(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ColorManager.kPrimaryColor.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  storeSession.activeStore?.storeName ??
                      'No Store Selected',
                  style: buildCustomStyle(
                    FontWeightManager.medium,
                    FontSize.s12,
                    0.16,
                    ColorManager.textColor,
                  ),
                ),
              ),
            ),
            if (isLoading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: ColorManager.kPrimaryColor,
                minHeight: 4,
              ),
            ],
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(
                status,
                style: buildCustomStyle(
                  FontWeightManager.regular,
                  FontSize.s10,
                  0.16,
                  ColorManager.textColor,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
