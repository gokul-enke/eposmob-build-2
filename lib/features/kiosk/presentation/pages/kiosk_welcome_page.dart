import 'package:flutter/material.dart';
import 'package:pos_machine/features/kiosk/presentation/pages/kiosk_home_page.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

/// Customer-facing entry point for a new kiosk session.
class KioskWelcomePage extends StatelessWidget {
  final VoidCallback? onStartOrder;

  const KioskWelcomePage({super.key, this.onStartOrder});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreSessionProvider>().activeStore;
    final storeName = store?.storeName?.trim().isNotEmpty == true
        ? store!.storeName!.trim()
        : 'Our store';

    return Scaffold(
      backgroundColor: ColorManager.kBgLightColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final compact = constraints.maxWidth < 650;

            return Stack(
              children: [
                const Positioned.fill(child: _WelcomeBackground()),
                Padding(
                  padding: EdgeInsets.all(compact ? 18 : 32),
                  child: Column(
                    children: [
                      _WelcomeTopBar(storeName: storeName),
                      SizedBox(height: compact ? 22 : 36),
                      Expanded(
                        child: landscape
                            ? _LandscapeWelcome(
                                storeName: storeName,
                                onStart: () => _start(context),
                              )
                            : _PortraitWelcome(
                                storeName: storeName,
                                onStart: () => _start(context),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _start(BuildContext context) {
    if (onStartOrder != null) {
      onStartOrder!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const KioskHomePage()),
    );
  }
}

class _WelcomeTopBar extends StatelessWidget {
  final String storeName;

  const _WelcomeTopBar({required this.storeName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Image.asset(
            'assets/logo/cloudposlogo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.storefront_rounded,
              color: ColorManager.kPrimaryColor,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            storeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.language_rounded, size: 24),
          label: const Text('English'),
          style: OutlinedButton.styleFrom(
            foregroundColor: ColorManager.kTextColor,
            minimumSize: const Size(132, 56),
            side: const BorderSide(color: Color(0xFFDDE3EF)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandscapeWelcome extends StatelessWidget {
  final String storeName;
  final VoidCallback onStart;

  const _LandscapeWelcome({required this.storeName, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: _WelcomeMessage(
              storeName: storeName,
              onStart: onStart,
              centered: false,
            ),
          ),
        ),
        const SizedBox(width: 26),
        const Expanded(flex: 4, child: _ProductMosaic()),
      ],
    );
  }
}

class _PortraitWelcome extends StatelessWidget {
  final String storeName;
  final VoidCallback onStart;

  const _PortraitWelcome({required this.storeName, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mosaicHeight = (constraints.maxHeight * 0.42).clamp(220.0, 420.0);

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: mosaicHeight,
                  child: const _ProductMosaic(),
                ),
                const SizedBox(height: 26),
                _WelcomeMessage(
                  storeName: storeName,
                  onStart: onStart,
                  centered: true,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeMessage extends StatelessWidget {
  final String storeName;
  final VoidCallback onStart;
  final bool centered;

  const _WelcomeMessage({
    required this.storeName,
    required this.onStart,
    required this.centered,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 650 ? 38.0 : 54.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: ColorManager.kPrimaryWithOpacity10,
            borderRadius: BorderRadius.circular(99),
          ),
          child: const Text(
            'QUICK • EASY • CONTACTLESS',
            style: TextStyle(
              color: ColorManager.kPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Welcome to\n$storeName',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: ColorManager.kTitleTextColor,
            fontSize: titleSize,
            height: 1.12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Browse the menu, build your order, and check out in just a few taps.',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: const TextStyle(
            color: ColorManager.kTextColor,
            fontSize: 18,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: centered ? double.infinity : 300,
          height: 72,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.touch_app_rounded, size: 28),
            label: const Text(
              'Start order',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5,
              shadowColor: ColorManager.kPrimaryColor.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Tap to begin',
          style: TextStyle(
            color: ColorManager.kTextColor.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _ProductMosaic extends StatelessWidget {
  const _ProductMosaic();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: const Row(
        children: [
          Expanded(
            child: _MosaicTile(
              asset: 'assets/images/Mask Group 11.png',
              alignment: Alignment.bottomCenter,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _MosaicTile(
                    asset: 'assets/images/Mask Group 7.png',
                    alignment: Alignment.center,
                  ),
                ),
                SizedBox(height: 14),
                Expanded(
                  child: _MosaicTile(
                    asset: 'assets/images/Mask Group 8.png',
                    alignment: Alignment.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MosaicTile extends StatelessWidget {
  final String asset;
  final Alignment alignment;

  const _MosaicTile({required this.asset, required this.alignment});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: const Color(0xFFF7F9FC),
        child: SizedBox.expand(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Image.asset(
              asset,
              fit: BoxFit.contain,
              alignment: alignment,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.fastfood_outlined,
                color: ColorManager.kGreyColor,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeBackground extends StatelessWidget {
  const _WelcomeBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFF), Color(0xFFEAF2FF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -100,
            top: -120,
            child: _Glow(size: 360, opacity: 0.10),
          ),
          Positioned(
            left: -130,
            bottom: -160,
            child: _Glow(size: 420, opacity: 0.07),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final double opacity;

  const _Glow({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryColor.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
