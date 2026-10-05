part of 'purchase_orders_responsive.dart';

class PurchaseOrdersResponsiveTable extends StatefulWidget {
  final Widget table;
  final double minWidth;

  const PurchaseOrdersResponsiveTable({
    super.key,
    required this.table,
    this.minWidth = 900,
  });

  @override
  State<PurchaseOrdersResponsiveTable> createState() =>
      _PurchaseOrdersResponsiveTableState();
}

class _PurchaseOrdersResponsiveTableState
    extends State<PurchaseOrdersResponsiveTable> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PurchaseOrdersContentCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= widget.minWidth) {
              return widget.table;
            }
            return Scrollbar(
              controller: _horizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _horizontalController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: widget.minWidth,
                  child: widget.table,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Label + value chip for mobile cards.
class PurchaseOrdersInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const PurchaseOrdersInfoChip({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s10,
              0.15,
              Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s12,
              0.15,
              ColorManager.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-column layout that stacks on phones.
class PurchaseOrdersTwoColumnLayout extends StatelessWidget {
  final Widget start;
  final Widget end;
  final double spacing;

  const PurchaseOrdersTwoColumnLayout({
    super.key,
    required this.start,
    required this.end,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (purchaseOrdersIsPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          start,
          SizedBox(height: spacing),
          end,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: start),
        SizedBox(width: spacing),
        Expanded(child: end),
      ],
    );
  }
}
