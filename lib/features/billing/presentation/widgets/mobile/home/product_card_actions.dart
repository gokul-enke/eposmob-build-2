import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Info (product details) and custom-add controls shared across market card layouts.
class ProductCardActions extends StatelessWidget {
  const ProductCardActions({
    super.key,
    this.onInfoTap,
    required this.onAddWithOptions,
    this.isDense = false,
    this.expandAdd = false,
  });

  final VoidCallback? onInfoTap;
  final VoidCallback? onAddWithOptions;
  final bool isDense;

  /// When true (grid cards), the Add button stretches to the remaining width.
  final bool expandAdd;

  @override
  Widget build(BuildContext context) {
    if (isDense) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (onInfoTap != null) ...[
            _InfoButton(onTap: onInfoTap, compact: true),
            const SizedBox(width: 4),
          ],
          _AddOptionsButton(onTap: onAddWithOptions, compact: true),
        ],
      );
    }

    final addButton = _AddOptionsButton(
      onTap: onAddWithOptions,
      compact: false,
      fixedWidth: expandAdd ? null : 72,
    );

    return Row(
      mainAxisSize: expandAdd ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (onInfoTap != null) ...[
          _InfoButton(onTap: onInfoTap, compact: false),
          const SizedBox(width: 4),
        ],
        if (expandAdd) Expanded(child: addButton) else addButton,
      ],
    );
  }
}

class _InfoButton extends StatelessWidget {
  const _InfoButton({
    required this.onTap,
    required this.compact,
  });

  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 32.0 : 40.0;
    final iconSize = compact ? 16.0 : 18.0;

    return Semantics(
      label: 'product_detail.view_details'.tr,
      button: true,
      child: Material(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 8 : 10),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.info_outline,
              size: iconSize,
              color: Colors.blueGrey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddOptionsButton extends StatelessWidget {
  const _AddOptionsButton({
    required this.onTap,
    required this.compact,
    this.fixedWidth,
  });

  final VoidCallback? onTap;
  final bool compact;
  final double? fixedWidth;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(compact ? 8 : 10);

    return Semantics(
      label: 'billing.add_product_custom'.tr,
      button: true,
      child: Material(
        color: Colors.green,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: compact ? 32 : (fixedWidth ?? 40),
              minHeight: compact ? 32 : 40,
            ),
            child: SizedBox(
              width: fixedWidth,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 0 : 10,
                  vertical: compact ? 0 : 6,
                ),
                child: Center(
                  child: compact
                      ? const Icon(Icons.add, size: 18, color: Colors.white)
                      : const Text(
                          'Add',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
