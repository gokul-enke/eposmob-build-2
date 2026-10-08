import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:pos_machine/responsive.dart';
import 'package:url_launcher/url_launcher.dart';

import 'order_packing_photo_viewer.dart';

TextStyle orderDetailSectionTitleStyle(BuildContext context) {
  final isMobile = ResponsiveWidget.isMobile(context);
  return buildCustomStyle(
    FontWeightManager.semiBold,
    isMobile ? FontSize.s14 : FontSize.s16,
    isMobile ? 0.21 : 0.24,
    ColorManager.textColor,
  );
}

void showOrderPackingPhotoViewer(BuildContext context, List<String> photos) {
  showDialog(
    context: context,
    builder: (dialogCtx) => OrderPackingPhotoViewer(photos: photos),
  );
}

Future<void> openOrderDetailExternal(
  BuildContext context,
  String url, {
  String failureMessageKey = 'sales_order_details.msg_video_open_failed',
}) async {
  final uri = Uri.tryParse(url);
  bool launched = false;
  if (uri != null) {
    // launchUrl throws (not just returns false) when no handler is
    // registered for the scheme, so both paths must be covered.
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error opening packing video: $e');
    }
  }
  if (!launched && context.mounted) {
    AppToast.error(context, failureMessageKey.tr);
  }
}
