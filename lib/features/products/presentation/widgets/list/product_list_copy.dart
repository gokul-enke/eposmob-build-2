import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'product_list_labels.dart';

class ProductListCopy extends StatelessWidget {
  const ProductListCopy(
      {super.key, required this.value, required this.message});
  final String? value;
  final String message;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(ProductListLabels.value(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body)),
        if (value?.isNotEmpty == true)
          IconButton(
              tooltip: message.tr,
              icon: const Icon(Icons.copy_outlined,
                  size: 18, color: AppColors.muted),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value!));
                if (context.mounted) AppToast.success(context, message.tr);
              }),
      ]);
}
