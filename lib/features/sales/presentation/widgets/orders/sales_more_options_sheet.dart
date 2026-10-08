import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/features/sales/domain/models/list_sales_order.dart';
import 'package:pos_machine/resources/color_manager.dart';

class SalesMoreOptionsSheet extends StatelessWidget {
  const SalesMoreOptionsSheet(
      {super.key,
      required this.order,
      required this.onShare,
      required this.onReturnItems,
      required this.onCancel,
      required this.onStatus,
      required this.onPayment});
  final ListOrderModelData order;
  final ValueChanged<BuildContext> onShare,
      onReturnItems,
      onCancel,
      onStatus,
      onPayment;
  @override
  Widget build(BuildContext context) {
    final ctx = context;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'sales.title_more_options'.tr,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                radius: 18,
                backgroundColor: ColorManager.kPrimaryColor.withOpacity(0.12),
                child:
                    const Icon(Icons.share, color: ColorManager.kPrimaryColor),
              ),
              title: Text('sales.btn_share'.tr),
              onTap: () async {
                onShare(ctx);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0x1AE53E3E), // ~10% opacity red
                child: Icon(Icons.assignment_return, color: Color(0xFFE53E3E)),
              ),
              title: Text('sales.btn_return'.tr),
              onTap: () async {
                onReturnItems(ctx);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0x1AE53E3E), // ~10% opacity red
                child: Icon(Icons.cancel_outlined, color: Color(0xFFE53E3E)),
              ),
              title: Text('sales.btn_cancel_order'.tr),
              onTap: () async {
                onCancel(ctx);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0x1A6A1B9A), // ~10% opacity purple
                child:
                    Icon(Icons.swap_horiz_outlined, color: Color(0xFF6A1B9A)),
              ),
              title: Text('sales.btn_change_order_status'.tr),
              onTap: () async {
                onStatus(ctx);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0x1A1E88E5), // ~10% opacity blue
                child: Icon(Icons.payment_outlined, color: Color(0xFF1E88E5)),
              ),
              title: Text('sales.btn_change_payment_status'.tr),
              onTap: () async {
                onPayment(ctx);
              },
            ),
            // ListTile(
            //   leading: const CircleAvatar(
            //     radius: 18,
            //     backgroundColor:
            //         Color(0x1A3F51B5), // ~10% opacity indigo
            //     child:
            //         Icon(Icons.download, color: Color(0xFF3F51B5)),
            //   ),
            //   title: const Text('Download Invoice'),
            //   onTap: () {
            //     Navigator.pop(ctx);
            //     // Handle download option
            //     String? invoiceHash = order.invoiceHash;
            //     if (invoiceHash != null) {
            //       downloadFile(invoiceHash);
            //     } else {
            //       if (context.mounted) {
            //         showScaffoldError(
            //           context: context,
            //           message:
            //               'Invoice not available for download.',
            //         );
            //       }
            //     }
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
