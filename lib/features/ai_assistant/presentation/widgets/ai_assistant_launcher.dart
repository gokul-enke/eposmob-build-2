import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/config/brand_config.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../state/ai_assistant_controller.dart';

/// The brand's mark for the assistant: the CloudPOS cloud for the default
/// brand, otherwise the white-label brand's own icon.
String get aiAssistantIconAsset => BrandConfig.isDefault
    ? 'assets/logo/cloudpos-mark.png'
    : BrandConfig.iconAsset;

/// Small "AI" pill on the launcher's top-right edge.
class _AiBadge extends StatelessWidget {
  const _AiBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('ai-assistant-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.surface, width: 1.5),
      ),
      child: const Text(
        'AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Round CloudPOS button that opens the assistant panel. It sits in the
/// sidebar's footer, so it only shows while the sidebar does and never covers
/// page content. A ring spins while an answer streams; a green dot marks an
/// answer that arrived while the panel was closed.
class AiAssistantLauncher extends StatelessWidget {
  const AiAssistantLauncher({super.key, this.controller, this.onOpen});

  static const double size = 48;

  /// Injected for tests; defaults to the app-wide instance.
  final AiAssistantController? controller;

  /// Runs instead of opening directly (the phone drawer closes itself first).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final chat = controller ?? AiAssistantController.instance;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) => Tooltip(
        message: 'ai_assistant.launcher_tooltip'.tr,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                key: const ValueKey('ai-assistant-launcher'),
                elevation: 3,
                shape: const CircleBorder(
                    side: BorderSide(color: AppColors.border)),
                color: AppColors.surface,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpen ?? chat.open,
                  child: Center(
                    child: Image.asset(aiAssistantIconAsset,
                        width: 32,
                        height: 32,
                        filterQuality: FilterQuality.medium),
                  ),
                ),
              ),
              if (chat.busy)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary),
                  ),
                ),
              // Marks the logo as the AI assistant rather than a brand link.
              const Positioned(
                top: -4,
                right: -8,
                child: IgnorePointer(child: _AiBadge()),
              ),
              if (chat.hasUnread && !chat.busy)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    key: const ValueKey('ai-assistant-unread'),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8EC63D),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
