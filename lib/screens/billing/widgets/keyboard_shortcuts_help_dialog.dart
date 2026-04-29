import 'package:flutter/material.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class _ShortcutItem {
  final String keyLabel;
  final String action;
  final String description;

  const _ShortcutItem({
    required this.keyLabel,
    required this.action,
    required this.description,
  });
}

class KeyboardShortcutsHelpDialog extends StatelessWidget {
  const KeyboardShortcutsHelpDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const KeyboardShortcutsHelpDialog(),
    );
  }

  static const List<_ShortcutItem> _billingShortcuts = [
    _ShortcutItem(
      keyLabel: 'F1',
      action: 'Clear Cart',
      description: 'Empties current order',
    ),
    _ShortcutItem(
      keyLabel: 'F8',
      action: 'Save Order',
      description: 'Saves without printing',
    ),
    _ShortcutItem(
      keyLabel: 'F9',
      action: 'Save Order and Print',
      description: 'Saves and prints receipt',
    ),
    _ShortcutItem(
      keyLabel: 'F6',
      action: 'Confirm and Print',
      description: 'Confirms order + prints',
    ),
    _ShortcutItem(
      keyLabel: 'F2',
      action: 'Confirm Order',
      description: 'Confirms without printing',
    ),
    _ShortcutItem(
      keyLabel: 'F7',
      action: 'Create New Order',
      description: 'Starts a fresh order',
    ),
    _ShortcutItem(
      keyLabel: 'Enter',
      action: 'Add Item',
      description: 'Adds product to cart',
    ),
    _ShortcutItem(
      keyLabel: 'F11',
      action: 'Focus search / barcode field',
      description: 'Jump cursor to search product',
    ),
    _ShortcutItem(
      keyLabel: 'F12',
      action: 'Switch Products ↔ Orders panel',
      description: 'Toggle right panel tabs',
    ),
  ];

  static const List<_ShortcutItem> _finalizeModalShortcuts = [
    _ShortcutItem(
      keyLabel: 'F3',
      action: 'Customer (step)',
      description: 'Jump to customer selection',
    ),
    _ShortcutItem(
      keyLabel: 'F4',
      action: 'Delivery (step)',
      description: 'Jump to delivery step',
    ),
    _ShortcutItem(
      keyLabel: 'F10',
      action: 'Discount (step)',
      description: 'Jump to discount step',
    ),
    _ShortcutItem(
      keyLabel: 'F5',
      action: 'Payment (step)',
      description: 'Jump to payment step',
    ),
    _ShortcutItem(
      keyLabel: 'F2',
      action: 'Confirm Order',
      description: 'Final confirm without print',
    ),
    _ShortcutItem(
      keyLabel: 'F6',
      action: 'Confirm & Print',
      description: 'Final confirm + print',
    ),
    _ShortcutItem(
      keyLabel: 'F8',
      action: 'Save Order',
      description: 'Save from modal',
    ),
    _ShortcutItem(
      keyLabel: 'F9',
      action: 'Save and Print',
      description: 'Save + print from modal',
    ),
    _ShortcutItem(
      keyLabel: 'Esc',
      action: 'Close modal',
      description: 'Dismiss finalize dialog',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 840, maxHeight: 720),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.help_outline,
                    color: ColorManager.kPrimaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Keyboard Shortcuts',
                    style: buildCustomStyle(
                      FontWeightManager.bold,
                      FontSize.s18,
                      0.30,
                      ColorManager.textColor,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('BILLING PAGE (MAIN ORDER SCREEN)'),
                    const SizedBox(height: 12),
                    _buildShortcutsGrid(_billingShortcuts),
                    const SizedBox(height: 24),
                    _buildSectionTitle('FINALIZE ORDER MODAL'),
                    const SizedBox(height: 12),
                    _buildShortcutsGrid(_finalizeModalShortcuts),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildShortcutsGrid(List<_ShortcutItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Always show 3 columns on desktop widths; 2 on smaller; 1 on very small
        int crossAxisCount;
        if (constraints.maxWidth > 640) {
          crossAxisCount = 3;
        } else if (constraints.maxWidth > 420) {
          crossAxisCount = 2;
        } else {
          crossAxisCount = 1;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 3.2,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _buildShortcutCard(items[index]);
          },
        );
      },
    );
  }

  Widget _buildShortcutCard(_ShortcutItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              item.keyLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ColorManager.textColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.action,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
