import 'package:flutter/material.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

// Global overlay entry to ensure messages appear above modals
OverlayEntry? _currentOverlayEntry;

ScaffoldMessengerState showScaffold({required BuildContext context, message}) {
  // Remove any existing overlay message
  _currentOverlayEntry?.remove();
  
  // Create a custom overlay message that will appear above modals
  _currentOverlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 20,
      right: 16, // Position on the right side
      child: Material(
        elevation: 1000,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 500, // Increased width for better readability
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ColorManager.kSuccessColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: buildCustomStyle(
                      FontWeightManager.medium, FontSize.s12, 0.12, Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () {
                  _currentOverlayEntry?.remove();
                  _currentOverlayEntry = null;
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  
  // Insert the overlay entry
  Overlay.of(context).insert(_currentOverlayEntry!);
  
  // Auto-remove after 2 seconds
  Future.delayed(const Duration(seconds: 2), () {
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
  });
  
  // Return ScaffoldMessenger for compatibility
  return ScaffoldMessenger.of(context);
}

ScaffoldMessengerState showScaffoldError(
    {required BuildContext context, required String message}) {
  // Remove any existing overlay message
  _currentOverlayEntry?.remove();
  
  // Create a custom overlay message that will appear above modals
  _currentOverlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 20,
      right: 16, // Position on the right side
      child: Material(
        elevation: 1000,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: 500, // Increased width for better readability
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: ColorManager.kErrorColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: buildCustomStyle(
                      FontWeightManager.medium, FontSize.s12, 0.12, Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: () {
                  _currentOverlayEntry?.remove();
                  _currentOverlayEntry = null;
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  
  // Insert the overlay entry
  Overlay.of(context).insert(_currentOverlayEntry!);
  
  // Auto-remove after 2 seconds
  Future.delayed(const Duration(seconds: 2), () {
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
  });
  
  // Return ScaffoldMessenger for compatibility
  return ScaffoldMessenger.of(context);
}
