import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../providers/auth_model.dart';
import '../../../resources/app_url.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../responsive.dart';
import '../../../services/order_document_service.dart';

/// "Order Documents" card on the order details screen.
///
/// The document endpoints stream PDFs behind auth headers, so each button
/// downloads the file first and then hands it to the system viewer. Downloads
/// can be large (the delivery note is ~800 KB), hence the per-button spinner.
class OrderDocumentsSection extends StatefulWidget {
  final String orderNumber;

  const OrderDocumentsSection({super.key, required this.orderNumber});

  @override
  State<OrderDocumentsSection> createState() => _OrderDocumentsSectionState();
}

class _OrderDocumentsSectionState extends State<OrderDocumentsSection> {
  /// Label of the document currently downloading, so only that button spins.
  String? _downloading;

  Future<void> _open({
    required String label,
    required String url,
    required String fallbackFileName,
  }) async {
    if (_downloading != null) return;

    final accessToken =
        Provider.of<AuthModel>(context, listen: false).token ?? '';
    if (accessToken.isEmpty) {
      _showMessage('sales_order_details.msg_session_expired'.tr, isError: true);
      return;
    }

    setState(() => _downloading = label);

    final result = await const OrderDocumentService().download(
      url: url,
      accessToken: accessToken,
      fallbackFileName: fallbackFileName,
    );

    if (!mounted) return;
    setState(() => _downloading = null);

    if (!result.isSuccess) {
      _showMessage(result.errorMessage ?? 'sales_order_details.msg_document_download_failed'.tr,
          isError: true);
      return;
    }

    final opened = await OpenFile.open(result.file!.path);
    if (!mounted) return;
    if (opened.type != ResultType.done) {
      _showMessage("${'sales_order_details.msg_document_saved_to'.tr} ${result.file!.path}");
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ColorManager.kRed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final orderNumber = widget.orderNumber;

    return BuildBoxShadowContainer(
      width: double.infinity,
      circleRadius: 7,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      margin: EdgeInsets.only(
        top: 8.0,
        left: isMobile ? 0 : 8,
        right: isMobile ? 0 : 8,
      ),
      offsetValue: const Offset(1, 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'sales_order_details.title_order_documents'.tr,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              isMobile ? FontSize.s14 : FontSize.s16,
              isMobile ? 0.21 : 0.24,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildDocumentButton(
                context,
                label: 'sales_order_details.btn_delivery_note'.tr,
                onTap: () => _open(
                  label: 'sales_order_details.btn_delivery_note'.tr,
                  url: APPUrl.orderDeliveryNote(orderNumber),
                  fallbackFileName: 'delivery-note-$orderNumber.pdf',
                ),
              ),
              _buildDocumentButton(
                context,
                label: 'sales_order_details.btn_delivery_invoice'.tr,
                onTap: () => _open(
                  label: 'sales_order_details.btn_delivery_invoice'.tr,
                  url: APPUrl.orderDeliveryInvoice(orderNumber),
                  fallbackFileName: 'delivery-invoice-$orderNumber.pdf',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    final isMobile = ResponsiveWidget.isMobile(context);
    final isBusy = _downloading == label;
    final isDisabled = _downloading != null && !isBusy;
    final color = isDisabled
        ? ColorManager.kPrimaryColor.withOpacity(0.4)
        : ColorManager.kPrimaryColor;

    return SizedBox(
      height: 40,
      width: isMobile ? double.infinity : 180,
      child: OutlinedButton(
        onPressed: _downloading != null ? null : onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(ColorManager.kPrimaryColor),
                ),
              )
            else
              Icon(Icons.download_outlined, size: 16, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s12,
                  0.18,
                  color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
