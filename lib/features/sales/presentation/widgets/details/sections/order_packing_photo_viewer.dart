import 'package:flutter/material.dart';
import 'package:get/get.dart';

class OrderPackingPhotoViewer extends StatefulWidget {
  final List<String> photos;

  const OrderPackingPhotoViewer({required this.photos});

  @override
  State<OrderPackingPhotoViewer> createState() =>
      OrderPackingPhotoViewerState();
}

class OrderPackingPhotoViewerState extends State<OrderPackingPhotoViewer> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Dialog(
      backgroundColor: Colors.black87,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${'sales_order_details.label_packing_photos'.tr}  ${_index + 1}/${widget.photos.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    widget.photos[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        'sales_order_details.msg_photo_load_failed'.tr,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
