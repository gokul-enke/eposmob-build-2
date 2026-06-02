import 'package:flutter/material.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

// Global overlay entry to ensure messages appear above modals
OverlayEntry? _currentOverlayEntry;
OverlayEntry? _loadingOverlayEntry;
String _notificationPosition = 'left';

void setNotificationPosition(String position) {
  const valid = {'left', 'center', 'right'};
  _notificationPosition = valid.contains(position) ? position : 'left';
}

double? _leftForDialog(bool isMobile, double screenWidth) {
  if (isMobile) return 16;
  if (_notificationPosition == 'left') return 16;
  if (_notificationPosition == 'center') return (screenWidth - 500) / 2;
  return null;
}

double? _rightForDialog(bool isMobile) {
  if (isMobile) return 16;
  if (_notificationPosition == 'right') return 16;
  return null;
}

ScaffoldMessengerState showScaffold({required BuildContext context, message}) {
  // Remove any existing overlay message
  _currentOverlayEntry?.remove();

  // Get screen width for responsive design
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  // Create a custom overlay message that will appear above modals
  _currentOverlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 20 + MediaQuery.of(context).padding.bottom,
      left: _leftForDialog(isMobile, screenWidth),
      right: _rightForDialog(isMobile),
      child: Material(
        elevation: 1000,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width:
              isMobile ? null : 500, // Full width on mobile, fixed on desktop
          constraints: isMobile
              ? BoxConstraints(
                  maxWidth: screenWidth - 32) // Account for left/right padding
              : const BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: ColorManager.kSuccessColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Text(
                  message,
                  style: buildCustomStyle(
                      FontWeightManager.medium,
                      isMobile ? FontSize.s11 : FontSize.s12,
                      0.12,
                      Colors.white),
                  maxLines: isMobile ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close,
                    color: Colors.white, size: isMobile ? 18 : 20),
                onPressed: () {
                  _currentOverlayEntry?.remove();
                  _currentOverlayEntry = null;
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                    minWidth: isMobile ? 20 : 24,
                    minHeight: isMobile ? 20 : 24),
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

void showLoadingOverlay(BuildContext context, {String message = 'Please wait...'}) {
  _loadingOverlayEntry?.remove();
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;
  _loadingOverlayEntry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.35),
          ),
        ),
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16 : 20,
                vertical: isMobile ? 14 : 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6),
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
                  Text(
                    message,
                    style: buildCustomStyle(
                      FontWeightManager.medium,
                      isMobile ? FontSize.s12 : FontSize.s13,
                      0.12,
                      Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
  Overlay.of(context).insert(_loadingOverlayEntry!);
}

void hideLoadingOverlay() {
  _loadingOverlayEntry?.remove();
  _loadingOverlayEntry = null;
}

ScaffoldMessengerState showScaffoldError(
    {required BuildContext context, required String message}) {
  // Remove any existing overlay message
  _currentOverlayEntry?.remove();

  // Get screen width for responsive design
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  // Create a custom overlay message that will appear above modals
  _currentOverlayEntry = OverlayEntry(
    builder: (context) => Positioned(
      bottom: 20 + MediaQuery.of(context).padding.bottom,
      left: _leftForDialog(isMobile, screenWidth),
      right: _rightForDialog(isMobile),
      child: Material(
        elevation: 1000,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width:
              isMobile ? null : 500, // Full width on mobile, fixed on desktop
          constraints: isMobile
              ? BoxConstraints(
                  maxWidth: screenWidth - 32) // Account for left/right padding
              : const BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
          decoration: BoxDecoration(
            color: ColorManager.kErrorColor.withOpacity(0.9),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Text(
                  message,
                  style: buildCustomStyle(
                      FontWeightManager.medium,
                      isMobile ? FontSize.s11 : FontSize.s12,
                      0.12,
                      Colors.white),
                  maxLines: isMobile ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close,
                    color: Colors.white, size: isMobile ? 18 : 20),
                onPressed: () {
                  _currentOverlayEntry?.remove();
                  _currentOverlayEntry = null;
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                    minWidth: isMobile ? 20 : 24,
                    minHeight: isMobile ? 20 : 24),
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
