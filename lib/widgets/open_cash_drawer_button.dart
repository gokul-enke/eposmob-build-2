import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/services/cash_drawer_service.dart';

class OpenCashDrawerButton extends StatefulWidget {
  final Color color;
  final double iconSize;
  final String? tooltip;
  final bool simulateIfNoPrinter;

  const OpenCashDrawerButton({
    super.key,
    required this.color,
    this.iconSize = 20,
    this.tooltip,
    this.simulateIfNoPrinter = true,
  });

  @override
  State<OpenCashDrawerButton> createState() => _OpenCashDrawerButtonState();
}

class _OpenCashDrawerButtonState extends State<OpenCashDrawerButton> {
  bool _isOpening = false;
  final CashDrawerService _cashDrawerService = const CashDrawerService();

  Future<void> _handleTap() async {
    if (_isOpening) {
      return;
    }

    setState(() {
      _isOpening = true;
    });

    try {
      await _cashDrawerService.openDrawer(
        context,
        simulateIfNoPrinter: widget.simulateIfNoPrinter,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip ??
          (Get.locale?.languageCode == 'ml'
              ? 'ക്യാഷ് ഡ്രോയർ തുറക്കുക'
              : 'Open cash drawer'),
      onPressed: _isOpening ? null : _handleTap,
      icon: _isOpening
          ? SizedBox(
              width: widget.iconSize,
              height: widget.iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
              ),
            )
          : Icon(
              Icons.payments,
              size: widget.iconSize,
              color: widget.color,
            ),
    );
  }
}