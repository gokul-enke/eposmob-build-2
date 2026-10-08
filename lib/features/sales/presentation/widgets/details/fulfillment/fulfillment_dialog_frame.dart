import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/components/build_round_button.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class FulfillmentDialogFrame extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? footer;
  final bool canDismiss;

  const FulfillmentDialogFrame({
    required this.title,
    required this.child,
    this.footer,
    this.canDismiss = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    return PopScope(
      canPop: canDismiss,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? screenSize.width - 48 : 920,
            maxHeight: screenSize.height - 48,
          ),
          child: BuildBoxShadowContainer(
            circleRadius: 16,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: buildCustomStyle(
                            FontWeightManager.semiBold,
                            FontSize.s20,
                            0.27,
                            ColorManager.textColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: canDismiss
                            ? () => Navigator.of(context).pop()
                            : null,
                        icon: const Icon(Icons.close, color: Colors.grey),
                        tooltip: MaterialLocalizations.of(context)
                            .closeButtonTooltip,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: child,
                  ),
                ),
                if (footer != null) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: footer!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FulfillmentFormGrid extends StatelessWidget {
  final List<Widget> children;

  const FulfillmentFormGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 620;
        final width =
            twoColumns ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}

class FulfillmentLoadFailure extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const FulfillmentLoadFailure({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              CustomRoundButton(
                title: 'sales_order_details.btn_retry'.tr,
                fct: onRetry,
                height: 36,
                width: 120,
                fontSize: FontSize.s11,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 17),
              ),
            ],
          ),
        ),
      );
}

class FulfillmentDialogActions extends StatelessWidget {
  final bool submitting;
  final String submitLabel;
  final VoidCallback onSubmit;

  const FulfillmentDialogActions({
    required this.submitting,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          const cancelWidth = 110.0;
          const submitWidth = 160.0;
          final stackButtons =
              constraints.maxWidth < cancelWidth + gap + submitWidth;
          final buttonWidth = stackButtons ? constraints.maxWidth : null;

          final cancelButton = CustomRoundButton(
            title: 'sales_order_details.btn_cancel'.tr,
            fct: submitting ? () {} : () => Navigator.of(context).pop(),
            height: 40,
            width: buttonWidth ?? cancelWidth,
            fontSize: FontSize.s12,
            boxColor: Colors.white,
            borderColor: ColorManager.kPrimaryColor,
            textColor: ColorManager.kPrimaryColor,
          );
          final submitButton = CustomRoundButton(
            title: submitLabel,
            fct: onSubmit,
            height: 40,
            width: buttonWidth ?? submitWidth,
            fontSize: FontSize.s12,
            isLoading: submitting,
          );

          if (stackButtons) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                cancelButton,
                const SizedBox(height: gap),
                submitButton,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              cancelButton,
              const SizedBox(width: gap),
              submitButton,
            ],
          );
        },
      );
}
