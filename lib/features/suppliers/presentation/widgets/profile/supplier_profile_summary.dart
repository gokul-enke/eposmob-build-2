import 'package:flutter/material.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/supplier.dart';
import 'info/supplier_info_format.dart';

/// Avatar, name and id of a supplier — the summary block of the profile
/// page (sidebar header on wide screens, header card on phones).
class SupplierProfileSummary extends StatelessWidget {
  const SupplierProfileSummary({super.key, required this.supplier});

  final Supplier supplier;

  @override
  Widget build(BuildContext context) {
    final name = SupplierInfoFormat.name(supplier.name);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppAvatar(name: supplier.name, semanticLabel: name, size: 52),
        const SizedBox(height: AppSpacing.sm),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppTextStyles.sectionTitle.copyWith(fontSize: 16),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(SupplierInfoFormat.id(supplier.id), style: AppTextStyles.caption),
      ],
    );
  }
}
