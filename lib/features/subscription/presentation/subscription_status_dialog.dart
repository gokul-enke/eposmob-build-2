import 'dart:io';

import 'package:flutter/material.dart';

import 'package:pos_machine/resources/asset_manager.dart';
import 'package:pos_machine/resources/color_manager.dart';

enum SubscriptionDialogVariant { warning, blocked, unavailable }

class SubscriptionStatusDialog extends StatelessWidget {
  const SubscriptionStatusDialog({
    required this.variant,
    required this.title,
    required this.message,
    required this.companyName,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.logoFilePath,
    this.logoUrl,
    super.key,
  });

  final SubscriptionDialogVariant variant;
  final String title;
  final String message;
  final String companyName;
  final String? logoFilePath;
  final String? logoUrl;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;

  Color get _accentColor => switch (variant) {
        SubscriptionDialogVariant.warning => const Color(0xFFD97706),
        SubscriptionDialogVariant.blocked => const Color(0xFFDC2626),
        SubscriptionDialogVariant.unavailable => const Color(0xFF64748B),
      };

  Color get _softAccentColor => switch (variant) {
        SubscriptionDialogVariant.warning => const Color(0xFFFFF7E6),
        SubscriptionDialogVariant.blocked => const Color(0xFFFFEEEE),
        SubscriptionDialogVariant.unavailable => const Color(0xFFF1F5F9),
      };

  IconData get _icon => switch (variant) {
        SubscriptionDialogVariant.warning => Icons.schedule_rounded,
        SubscriptionDialogVariant.blocked => Icons.lock_outline_rounded,
        SubscriptionDialogVariant.unavailable => Icons.cloud_off_rounded,
      };

  String? get _eyebrow => switch (variant) {
        SubscriptionDialogVariant.warning => null,
        SubscriptionDialogVariant.blocked => null,
        SubscriptionDialogVariant.unavailable => 'VERIFICATION REQUIRED',
      };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const Key('subscription-status-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Material(
          color: Colors.white,
          elevation: 24,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BrandHeader(
                  companyName: companyName,
                  logoFilePath: logoFilePath,
                  logoUrl: logoUrl,
                ),
                const SizedBox(height: 22),
                const Divider(height: 1, color: Color(0xFFE8EDF3)),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _softAccentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, size: 30, color: _accentColor),
                  ),
                ),
                const SizedBox(height: 18),
                if (_eyebrow != null) ...[
                  Text(
                    _eyebrow!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF5B6474),
                      fontSize: 14.5,
                      height: 1.55,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                _PrimaryButton(
                  label: primaryLabel,
                  onPressed: onPrimaryPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.companyName,
    this.logoFilePath,
    this.logoUrl,
  });

  final String companyName;
  final String? logoFilePath;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E9F1)),
          ),
          child: _buildLogo(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companyName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 16,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'POS Subscription Management',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF7A8494),
                  fontSize: 11.5,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogo() {
    final localPath = logoFilePath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _networkOrFallbackLogo(),
        );
      }
    }
    return _networkOrFallbackLogo();
  }

  Widget _networkOrFallbackLogo() {
    final remoteUrl = logoUrl?.trim();
    if (remoteUrl != null && remoteUrl.isNotEmpty) {
      return Image.network(
        remoteUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackLogo(),
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : _fallbackLogo(),
      );
    }
    return _fallbackLogo();
  }

  Widget _fallbackLogo() => Image.asset(
        ImageAssets.posImageLogo,
        fit: BoxFit.contain,
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: ColorManager.kPrimaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
