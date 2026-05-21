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

class _ShortcutSection {
  final String title;
  final List<_ShortcutItem> items;

  const _ShortcutSection({
    required this.title,
    required this.items,
  });
}

enum KeyboardShortcutsHelpMode { standard, restaurant }

class KeyboardShortcutsHelpDialog extends StatelessWidget {
  const KeyboardShortcutsHelpDialog({
    super.key,
    this.mode = KeyboardShortcutsHelpMode.standard,
  });

  final KeyboardShortcutsHelpMode mode;

  static void show(
    BuildContext context, {
    KeyboardShortcutsHelpMode mode = KeyboardShortcutsHelpMode.standard,
  }) {
    showDialog(
      context: context,
      builder: (_) => KeyboardShortcutsHelpDialog(mode: mode),
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
      keyLabel: 'Alt + D',
      action: 'Open Cash Drawer',
      description: 'Trigger printer to open the cash drawer',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + A',
      action: 'Focus Category / Barcode',
      description:
          'Restaurant: first category. Billing: barcode input when enabled',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + S',
      action: 'Focus Search Product field',
      description: 'Jump cursor to product search for fast item entry',
    ),
  ];

  static const List<_ShortcutItem> _restaurantGlobalShortcuts = [
    _ShortcutItem(
      keyLabel: 'Ctrl + H',
      action: 'Open this Help',
      description: 'Show the keyboard shortcuts dialog',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + K',
      action: 'Toggle Virtual Keyboard',
      description: 'Show/hide the on-screen keyboard panel',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + D',
      action: 'Current Cart',
      description: 'Return the order panel to Cart',
    ),
    _ShortcutItem(
      keyLabel: 'Alt + D',
      action: 'Open Cash Drawer',
      description: 'Trigger printer to open the cash drawer',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + A',
      action: 'Focus Categories',
      description: 'Focus the menu category row',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + S',
      action: 'Focus Search',
      description: 'Jump cursor to menu item search',
    ),
  ];

  static const List<_ShortcutItem> _standardBillingShortcuts = [
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
      action: 'Save / Offline Print',
      description: 'Online: save order. Offline: save and print',
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
      keyLabel: 'F12',
      action: 'Activate sidebar keyboard mode',
      description: 'Switch focus to right panel (Tab to cycle, Esc to exit)',
    ),
  ];

  static const List<_ShortcutItem> _standardCartShortcuts = [
    _ShortcutItem(
      keyLabel: 'Delete',
      action: 'Remove Cart Item',
      description: 'Remove focused cart item',
    ),
    _ShortcutItem(
      keyLabel: '+ / -',
      action: 'Adjust Cart Qty',
      description: 'Increase or decrease quantity of focused cart row',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + U',
      action: 'Focus Cart Unit',
      description: 'Focus Unit selector for the selected cart row',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + Q',
      action: 'Focus Cart Qty',
      description: 'Focus quantity edit for the selected cart row',
    ),
    _ShortcutItem(
      keyLabel: 'Ctrl + P',
      action: 'Focus Cart Price',
      description: 'Focus price edit for the selected cart row',
    ),
    _ShortcutItem(
      keyLabel: 'H',
      action: 'Purchase History (cart row)',
      description: 'Open customer purchase history for selected cart row',
    ),
  ];

  static const List<_ShortcutItem> _restaurantBillingShortcuts = [
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
      action: 'Save / Offline Print',
      description: 'Online: save order. Offline: save and print',
    ),
    _ShortcutItem(
      keyLabel: 'F3',
      action: 'Select Customer',
      description: 'Open customer selection',
    ),
    _ShortcutItem(
      keyLabel: 'F4',
      action: 'Dining / Delivery',
      description: 'Counter mode: delivery selector. Dining mode: table picker',
    ),
    _ShortcutItem(
      keyLabel: 'F5',
      action: 'Payment Step',
      description: 'Open checkout at payment step when possible',
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
      keyLabel: 'F10',
      action: 'Discount Step',
      description: 'Open checkout at discount step when possible',
    ),
    _ShortcutItem(
      keyLabel: 'F12',
      action: 'Toggle Tables Panel',
      description: 'Desktop: show/hide tables panel. Mobile: switch panels',
    ),
  ];

  static const List<_ShortcutItem> _restaurantCartShortcuts = [
    _ShortcutItem(
      keyLabel: 'Tab / Shift + Tab',
      action: 'Move through cart controls',
      description:
          'Cycle through price, quantity, comment, remove, and footer buttons',
    ),
    _ShortcutItem(
      keyLabel: 'Enter / Space',
      action: 'Activate focused control',
      description: 'Press the focused cart button or footer action',
    ),
    _ShortcutItem(
      keyLabel: 'F1 / F8 / F2 / F6',
      action: 'Footer actions',
      description: 'Clear, Save, Confirm, or Confirm and Print',
    ),
  ];

  static const List<_ShortcutItem> _sharedShortcuts = [
    _ShortcutItem(
      keyLabel: 'Tab',
      action: 'Navigate fields',
      description: 'Move focus forward through active sections',
    ),
    _ShortcutItem(
      keyLabel: 'Shift + Tab',
      action: 'Navigate reverse',
      description: 'Move focus backward through active sections',
    ),
    _ShortcutItem(
      keyLabel: 'Arrow Keys',
      action: 'Navigate lists/grids',
      description: 'Move in category row, product grid, cart, and modal lists',
    ),
    _ShortcutItem(
      keyLabel: 'Enter / Space',
      action: 'Activate selected item',
      description: 'Add product, select tile, or press focused action',
    ),
    _ShortcutItem(
      keyLabel: 'Esc',
      action: 'Close / return focus',
      description: 'Close modal or return focus to product entry',
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
    final billingShortcuts = mode == KeyboardShortcutsHelpMode.restaurant
        ? _restaurantBillingShortcuts
        : _standardBillingShortcuts;
    final cartShortcuts = mode == KeyboardShortcutsHelpMode.restaurant
        ? _restaurantCartShortcuts
        : _standardCartShortcuts;
    final globalShortcuts = mode == KeyboardShortcutsHelpMode.restaurant
        ? _restaurantGlobalShortcuts
        : _globalShortcuts;
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
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
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
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFocusHighlightSetting(context),
                      const SizedBox(height: 14),
                      _buildSectionsSheet(
                        [
                          _ShortcutSection(
                            title: 'Global',
                            items: globalShortcuts,
                          ),
                          _ShortcutSection(
                            title: mode == KeyboardShortcutsHelpMode.restaurant
                                ? 'Billing (Restaurant)'
                                : 'Billing (Standard)',
                            items: billingShortcuts,
                          ),
                          _ShortcutSection(
                            title: mode == KeyboardShortcutsHelpMode.restaurant
                                ? 'Cart (Restaurant)'
                                : 'Cart (Standard)',
                            items: cartShortcuts,
                          ),
                          const _ShortcutSection(
                            title: 'Shared',
                            items: _sharedShortcuts,
                          ),
                          const _ShortcutSection(
                            title: 'Checkout Modal',
                            items: _finalizeModalShortcuts,
                          ),
                          const _ShortcutSection(
                            title: 'Add Product Modal',
                            items: _addProductModalShortcuts,
                          ),
                        ],
                      ),
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
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(8),
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
            child: Text(
              'Keyboard focus outline',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ColorManager.textColor,
              ),
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

  Widget _buildSectionsSheet(List<_ShortcutSection> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double gap = 14;
        final bool threeCols = constraints.maxWidth > 980;
        final bool twoCols = constraints.maxWidth > 640;

        if (!twoCols) {
          return Column(
            children: sections
                .map((section) => Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: _buildShortcutSection(section),
                    ))
                .toList(),
          );
        }

        if (threeCols && sections.length >= 6) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildShortcutSection(sections[0]),
                    const SizedBox(height: gap),
                    _buildShortcutSection(sections[5]),
                  ],
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    _buildShortcutSection(sections[1]),
                    const SizedBox(height: gap),
                    _buildShortcutSection(sections[3]),
                  ],
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    _buildShortcutSection(sections[2]),
                    const SizedBox(height: gap),
                    _buildShortcutSection(sections[4]),
                  ],
                ),
              ),
            ],
          );
        }

        // Two-column fallback: split sections evenly.
        final List<_ShortcutSection> left = [];
        final List<_ShortcutSection> right = [];
        for (int i = 0; i < sections.length; i++) {
          (i.isEven ? left : right).add(sections[i]);
        }

        Widget buildCol(List<_ShortcutSection> col) {
          return Column(
            children: col
                .map((section) => Padding(
                      padding: const EdgeInsets.only(bottom: gap),
                      child: _buildShortcutSection(section),
                    ))
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: buildCol(left)),
            const SizedBox(width: gap),
            Expanded(child: buildCol(right)),
          ],
        );
      },
    );
  }

  Widget _buildShortcutSection(_ShortcutSection section) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...section.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildKeyChip(item.keyLabel),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.action,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ColorManager.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyChip(String keyLabel) {
    return SizedBox(
      width: 96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: ColorManager.kPrimaryColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: ColorManager.kPrimaryColor.withValues(alpha: 0.9),
          ),
        ),
        child: Text(
          keyLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
