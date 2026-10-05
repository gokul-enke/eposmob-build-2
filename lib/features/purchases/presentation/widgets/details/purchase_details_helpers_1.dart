part of 'purchase_details_view.dart';

class _TableColumns {
  const _TableColumns({
    required this.product,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.batch,
    required this.expiry,
    required this.status,
  });

  final double product;
  final double category;
  final double quantity;
  final double unitPrice;
  final double total;
  final double batch;
  final double expiry;
  final double status;

  factory _TableColumns.forWidth(double width) {
    final unit = width / PurchaseDetailsView._minimumTableWidth;
    return _TableColumns(
      product: PurchaseDetailsView._productColumnWidth * unit,
      category: PurchaseDetailsView._categoryColumnWidth * unit,
      quantity: PurchaseDetailsView._quantityColumnWidth * unit,
      unitPrice: PurchaseDetailsView._unitPriceColumnWidth * unit,
      total: PurchaseDetailsView._totalColumnWidth * unit,
      batch: PurchaseDetailsView._batchColumnWidth * unit,
      expiry: PurchaseDetailsView._expiryColumnWidth * unit,
      status: PurchaseDetailsView._statusColumnWidth * unit,
    );
  }
}

class _EmptyPurchaseState extends StatelessWidget {
  const _EmptyPurchaseState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'purchase_order.no_purchase_details'.tr,
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s18,
                0.2,
                ColorManager.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'purchase_order.open_purchase_order_hint'.tr,
              style: buildCustomStyle(
                FontWeightManager.medium,
                FontSize.s13,
                0.2,
                Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _TopActionButton(
              label: 'purchase_order.back'.tr,
              icon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7EAEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 20, 26, 18),
            child: Text(
              title,
              style: buildCustomStyle(
                FontWeightManager.bold,
                FontSize.s16,
                0.2,
                ColorManager.textColor,
              ),
            ),
          ),
          Container(
            height: 1,
            color: const Color(0xFFF0F2F4),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            FontWeightManager.semiBold,
            FontSize.s14,
            0.2,
            ColorManager.textColor,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s14,
            0.2,
            Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _PurchaseTotalsSummary extends StatelessWidget {
  const _PurchaseTotalsSummary({
    required this.grossAmount,
    required this.discountAmount,
    required this.netPayable,
    required this.currency,
  });

  final String grossAmount;
  final String discountAmount;
  final String netPayable;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final discount = _DisplayFormatter.toDouble(discountAmount);

    return Column(
      children: [
        _buildRow(
          'purchase_order.gross_total'.tr,
          _DisplayFormatter.currency(grossAmount, currency: currency),
        ),
        if (discount > 0) ...[
          const SizedBox(height: 8),
          _buildRow(
            'purchase_order.overall_discount'.tr,
            '- ${_DisplayFormatter.currency(discount, currency: currency)}',
            valueColor: Colors.red.shade700,
          ),
        ],
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1),
        ),
        _buildRow(
          'purchase_order.net_payable'.tr,
          _DisplayFormatter.currency(netPayable, currency: currency),
          emphasize: true,
          valueColor: ColorManager.kPrimaryColor,
        ),
      ],
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool emphasize = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: buildCustomStyle(
            emphasize ? FontWeightManager.bold : FontWeightManager.medium,
            emphasize ? FontSize.s14 : FontSize.s12,
            0.2,
            ColorManager.textColor,
          ),
        ),
        Text(
          value,
          style: buildCustomStyle(
            emphasize ? FontWeightManager.bold : FontWeightManager.semiBold,
            emphasize ? FontSize.s15 : FontSize.s12,
            0.2,
            valueColor ?? ColorManager.textColor,
          ),
        ),
      ],
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColorManager.kPrimaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: FontConstants.fontFamily,
            fontSize: FontSize.s13,
            fontWeight: FontWeightManager.semiBold,
          ),
        ),
      ),
    );
  }
}

class _TableRowContainer extends StatelessWidget {
  const _TableRowContainer({
    this.color,
    required this.width,
    required this.child,
  });

  final Color? color;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: child,
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell({required this.text, required this.width});

  final String text;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: buildCustomStyle(
            FontWeightManager.medium,
            FontSize.s12,
            0.6,
            const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
