import 'package:flutter/material.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import 'package:pos_machine/providers/billing_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onClearCart;
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final VoidCallback onConfirmOrder;
  final VoidCallback onSaveAndPrint;

  const ActionButtons({
    super.key,
    required this.onClearCart,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    required this.onConfirmOrder,
    required this.onSaveAndPrint,
  });

  @override
  Widget build(BuildContext context) {
    final bp = Provider.of<BillingProvider>(context, listen: true);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            text: 'Clear Cart',
            color: ColorManager.kButtonRed,
            onPressed: onClearCart,
            isLoading: bp.isLoadingClearCart,
          ),
          _buildActionButton(
            text: 'Save Order',
            color: ColorManager.kButtonYellow,
            onPressed: onSaveOrder,
            isLoading: bp.isLoadingSaveOrder,
          ),
          if (bp.hasInternet) ...[
            if (Provider.of<AppSettingsProvider>(context, listen: false)
                    .appSettings
                    ?.showConfirmOrderAndPrintButton ??
                true)
              _buildActionButton(
                text: 'Confirm and Print',
                color: ColorManager.kButtonBlue,
                onPressed: onCreateOrderAndPrint,
                isLoading: bp.isLoadingCreateOrder,
              ),
            if (Provider.of<AppSettingsProvider>(context, listen: false)
                    .appSettings
                    ?.showConfirmOrderButton ??
                true)
              _buildActionButton(
                text: 'Confirm Order',
                color: ColorManager.kButtonGreen,
                onPressed: onConfirmOrder,
                isLoading: bp.isLoadingConfirmOrder,
              ),
          ],
          if (!bp.hasInternet) ...[
            _buildActionButton(
              text: 'Save and Print',
              color: ColorManager.kButtonYellow,
              onPressed: onSaveAndPrint,
              isLoading: bp.isLoadingSaveOrderAndPrint,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          onTap: isLoading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
