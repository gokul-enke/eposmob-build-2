import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/providers/keyboard_focus_highlight_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:provider/provider.dart';

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

  /// Global keyboard shortcuts that work anywhere on the billing page.
  static const List<_ShortcutItem> _globalShortcuts = [
    _ShortcutItem(
      keyLabel: 'Ctrl + H',
      action: 'Open this Help',
      description: 'Show or hide the keyboard shortcuts dialog',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + K',
      action: 'Toggle Virtual Keyboard',
      description: 'Show/hide the on-screen keyboard panel',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + D',
      action: 'Focus Cart Table',
      description: 'Focus cart on first row Item Name cell',
    ),
    _ShortcutItem(
      keyLabel: 'D',
      action: 'Open Cash Drawer',
      description: 'Trigger printer to open the cash drawer',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + A',
      action: 'Focus Barcode field',
      description: 'Jump cursor to barcode input when barcode sales is enabled',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + S',
      action: 'Focus Search Product field',
      description: 'Jump cursor to product search for fast item entry',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + U',
      action: 'Focus Cart Unit',
      description: 'Focus Unit selector for the selected cart row',
    ),
  ];

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
      keyLabel: 'F11',
      action: 'Legacy shortcut',
      description: 'Reserved for existing keyboard workflows',
    ),
    _ShortcutItem(
      keyLabel: 'Enter',
      action: 'Add Item',
      description: 'Adds product to cart',
    ),
    _ShortcutItem(
      keyLabel: 'F12',
      action: 'Activate sidebar keyboard mode',
      description: 'Switch focus to right panel (Tab to cycle, Esc to exit)',
    ),
    _ShortcutItem(
      keyLabel: 'Tab',
      action: 'Navigate fields',
      description: 'Move focus forward through input fields and buttons',
    ),
    _ShortcutItem(
      keyLabel: 'Shift + Tab',
      action: 'Navigate fields (reverse)',
      description: 'Move focus backward through input fields and buttons',
    ),
    _ShortcutItem(
      keyLabel: 'Arrow Keys',
      action: 'Navigate lists',
      description: 'Move up/down in cart, customer, or product lists',
    ),
    _ShortcutItem(
      keyLabel: 'H',
      action: 'Purchase History (cart row)',
      description: 'Open customer purchase history for selected cart row',
    ),
    _ShortcutItem(
      keyLabel: 'Esc',
      action: 'Return to product entry',
      description: 'Exit sidebar mode or refocus Search Product field',
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
      keyLabel: 'Arrow Keys',
      action: 'Navigate customer / delivery tiles',
      description: 'Move focus across customer grid or delivery methods',
    ),
    _ShortcutItem(
      keyLabel: 'Enter / Space',
      action: 'Select highlighted item',
      description: 'Pick a customer, delivery method, or toggle payment',
    ),
    _ShortcutItem(
      keyLabel: 'Esc',
      action: 'Close modal',
      description: 'Dismiss finalize dialog',
    ),
  ];

  static const List<_ShortcutItem> _addProductModalShortcuts = [
    _ShortcutItem(
      keyLabel: 'F4',
      action: 'Close Modal',
      description: 'Dismiss add product dialog',
    ),
    _ShortcutItem(
      keyLabel: 'F8',
      action: 'Save & Create',
      description: 'Save and keep modal open',
    ),
    _ShortcutItem(
      keyLabel: 'F9',
      action: 'Save',
      description: 'Save and close modal',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Wrap in Focus to capture Esc and dismiss the dialog. autofocus ensures
    // the listener is active immediately after the help opens (e.g. via
    // Ctrl+H on the billing page or the toolbar icon).
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 580),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('GLOBAL ACTIONS'),
                      const SizedBox(height: 8),
                      _buildFocusHighlightSetting(context),
                      const SizedBox(height: 12),
                      _buildShortcutsGrid(_globalShortcuts),
                      const SizedBox(height: 16),
                      _buildSectionTitle('BILLING PAGE (MAIN ORDER SCREEN)'),
                      const SizedBox(height: 8),
                      _buildShortcutsGrid(_billingShortcuts),
                      const SizedBox(height: 16),
                      _buildSectionTitle('FINALIZE ORDER MODAL'),
                      const SizedBox(height: 8),
                      _buildShortcutsGrid(_finalizeModalShortcuts),
                      const SizedBox(height: 16),
                      _buildSectionTitle('ADD PRODUCT MODAL'),
                      const SizedBox(height: 8),
                      _buildShortcutsGrid(_addProductModalShortcuts),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFocusHighlightSetting(BuildContext context) {
    KeyboardFocusHighlightProvider? provider;
    bool enabled = true;
    try {
      provider = Provider.of<KeyboardFocusHighlightProvider>(context);
      enabled = provider.enabled;
    } on ProviderNotFoundException {
      provider = null;
      enabled = true;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.center_focus_strong,
            color: ColorManager.kPrimaryColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keyboard focus outline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ColorManager.textColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Show blue outline on focused fields, buttons, and cart table',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeThumbColor: ColorManager.kPrimaryColor,
            onChanged: provider?.setEnabled,
          ),
        ],
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
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 4.2,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              item.keyLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ColorManager.textColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorManager.textColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
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
