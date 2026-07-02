import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_home_widget.dart';

class MobileHomeTab extends StatefulWidget {
  final GlobalKey autocompleteProductKey;
  final Function(String) onProcessBarcode;
  final VoidCallback onClearProductFields;
  final VoidCallback focusTextField;
  final VoidCallback onClearCart;

  const MobileHomeTab({
    super.key,
    required this.autocompleteProductKey,
    required this.onProcessBarcode,
    required this.onClearProductFields,
    required this.focusTextField,
    required this.onClearCart,
  });

  @override
  State<MobileHomeTab> createState() => _MobileHomeTabState();
}

class _MobileHomeTabState extends State<MobileHomeTab> {
  @override
  Widget build(BuildContext context) {
    return MarketHomeWidget(
      autocompleteProductKey: widget.autocompleteProductKey,
      onProcessBarcode: widget.onProcessBarcode,
      onClearProductFields: widget.onClearProductFields,
      focusTextField: widget.focusTextField,
    );
  }
}
