import 'package:flutter/material.dart';

import '../resources/color_manager.dart';
import '../resources/font_manager.dart';
import '../resources/style_manager.dart';

ScaffoldMessengerState showScaffold({required BuildContext context, message}) {
  return ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.up,
        closeIconColor: Colors.white,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        margin: EdgeInsets.only(
          bottom: 20,
          left: MediaQuery.of(context).size.width /
              2, // Start from the middle of the screen
          right: 16, // Small right margin
        ),
        backgroundColor: ColorManager.kSuccessColor.withOpacity(0.9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
        content: Row(
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
          ],
        )));
}

ScaffoldMessengerState showScaffoldError(
    {required BuildContext context, required String message}) {
  return ScaffoldMessenger.of(context)
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(
        showCloseIcon: true,
        dismissDirection: DismissDirection.up,
        closeIconColor: Colors.white,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        margin: EdgeInsets.only(
          bottom: 20,
          left: MediaQuery.of(context).size.width /
              2, // Start from the middle of the screen
          right: 16, // Small right margin
        ),
        backgroundColor: ColorManager.kErrorColor.withOpacity(0.9),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.white.withOpacity(0.2), width: 1)),
        content: Row(
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
          ],
        )));
}
