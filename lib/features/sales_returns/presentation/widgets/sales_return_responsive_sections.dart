part of 'sales_return_responsive.dart';

class SalesReturnTwoColumnLayout extends StatelessWidget {
  final Widget start;
  final Widget end;
  final double spacing;

  const SalesReturnTwoColumnLayout({
    super.key,
    required this.start,
    required this.end,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isPhone = salesReturnIsPhone(context);

    if (isPhone) {
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

/// Action buttons that stack on phones.
class SalesReturnActionRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment alignment;

  const SalesReturnActionRow({
    super.key,
    required this.children,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    if (salesReturnIsPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }

    return Row(
      mainAxisAlignment: alignment,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          children[i],
        ],
      ],
    );
  }
}

/// Responsive row of order detail chips (stacks on phone).
class SalesReturnDetailGrid extends StatelessWidget {
  final List<Widget> children;

  const SalesReturnDetailGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final isPhone = salesReturnIsPhone(context);

    if (isPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Step hint bar that wraps on narrow screens.
class SalesReturnStepBar extends StatelessWidget {
  final List<Widget> steps;

  const SalesReturnStepBar({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorManager.kPrimaryColor.withOpacity(0.2),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: steps,
      ),
    );
  }
}

/// Label pill used in section headers.
class SalesReturnLabelPill extends StatelessWidget {
  final String label;
  final Color color;

  const SalesReturnLabelPill({
    super.key,
    required this.label,
    this.color = ColorManager.kPrimaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: buildCustomStyle(
          FontWeightManager.semiBold,
          FontSize.s11,
          0.25,
          color,
        ),
      ),
    );
  }
}
