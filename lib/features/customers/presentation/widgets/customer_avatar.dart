import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../domain/customer_display.dart';
import 'customer_labels.dart';

/// [AppAvatar] for a customer: initial of the real name, `#` when unnamed.
class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({super.key, required this.name, this.size = 40});

  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      name: CustomerNames.realName(name) ?? '',
      semanticLabel: CustomerLabels.avatarSemantics(name),
      size: size,
    );
  }
}

/// B2C / B2B pill.
class CustomerTypeBadge extends StatelessWidget {
  const CustomerTypeBadge({super.key, required this.type});

  final String? type;

  @override
  Widget build(BuildContext context) {
    final customerType = CustomerType.parse(type);
    return AppBadge(
      label: CustomerLabels.type(customerType),
      tone: customerType == CustomerType.b2b
          ? AppBadgeTone.success
          : AppBadgeTone.info,
      semanticLabel:
          'customers.type_semantics'.trParams({'type': customerType.apiValue}),
    );
  }
}
