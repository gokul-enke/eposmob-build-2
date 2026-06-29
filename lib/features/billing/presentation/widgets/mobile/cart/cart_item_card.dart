import 'package:flutter/material.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';

class CartItemCard extends StatelessWidget {
  const CartItemCard({
    super.key,
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
  });

  final LocalCartItem item;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  String? get _imageUrl {
    final attachments = item.product.attachment ?? const <Attachment>[];
    if (attachments.isEmpty) return null;
    final raw = attachments.first.file?.toString().trim().isNotEmpty == true
        ? attachments.first.file.toString().trim()
        : attachments.first.filePath?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return null;
  }

  String get _displayQuantity {
    final quantity = item.displayQuantity;
    if (quantity % 1 == 0) {
      return quantity.toInt().toString();
    }
    return quantity.toStringAsFixed(1).replaceAll(RegExp(r'0$'), '');
  }

  String get _lineTotal {
    final total = (item.price ?? 0) * item.quantity;
    return total.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 78,
              height: 78,
              child: _imageUrl == null
                  ? _fallbackImage()
                  : Image.network(
                      _imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _fallbackImage();
                      },
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.product.productName ?? 'Unnamed Product',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chat_bubble,
                      size: 15,
                      color: Colors.blueGrey.shade100,
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: onRemove,
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _QuantityButton(
                      icon: Icons.remove,
                      filled: false,
                      onTap: onDecrease,
                    ),
                    Container(
                      width: 34,
                      alignment: Alignment.center,
                      child: Text(
                        _displayQuantity,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _QuantityButton(
                      icon: Icons.add,
                      filled: true,
                      onTap: onIncrease,
                    ),
                    const Spacer(),
                    Text(
                      _lineTotal,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF1764C0),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      color: Colors.blueGrey.shade50,
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: 30,
        color: Colors.blueGrey.shade200,
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? const Color(0xFF2E69C8) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : const Color(0xFF2E69C8),
          ),
        ),
      ),
    );
  }
}
