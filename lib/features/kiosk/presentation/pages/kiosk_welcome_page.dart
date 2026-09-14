import 'package:flutter/material.dart';
import 'package:pos_machine/features/billing/presentation/widgets/mobile/home/market_product_display.dart';
import 'package:pos_machine/features/kiosk/presentation/pages/kiosk_home_page.dart';
import 'package:pos_machine/features/kiosk/presentation/widgets/kiosk_language_sheet.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:provider/provider.dart';

/// Customer-facing entry point for a new kiosk session.
class KioskWelcomePage extends StatelessWidget {
  final VoidCallback? onStartOrder;

  const KioskWelcomePage({super.key, this.onStartOrder});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StoreSessionProvider>().activeStore;
    final products = _featuredProducts(
      context.watch<LocalProductProvider>().sellableProducts,
    );
    final storeName = store?.storeName?.trim().isNotEmpty == true
        ? store!.storeName!.trim()
        : 'Our store';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final landscape = constraints.maxWidth > constraints.maxHeight;
            final compact = constraints.maxWidth < 680;
            final pagePadding = compact ? 20.0 : 36.0;

            return Stack(
              children: [
                const Positioned.fill(child: _WelcomeBackground()),
                Padding(
                  padding: EdgeInsets.all(pagePadding),
                  child: Column(
                    children: [
                      _WelcomeTopBar(storeName: storeName),
                      SizedBox(height: compact ? 20 : 32),
                      Expanded(
                        child: landscape
                            ? _LandscapeWelcome(
                                storeName: storeName,
                                products: products,
                                onStart: () => _start(context),
                              )
                            : _PortraitWelcome(
                                storeName: storeName,
                                products: products,
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
    final compact = MediaQuery.sizeOf(context).width < 520;
    return Row(
      children: [
        Container(
          width: compact ? 52 : 60,
          height: compact ? 52 : 60,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE3EAF4)),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                storeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ColorManager.kTitleTextColor,
                  fontSize: compact ? 20 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (!compact)
                const Text(
                  'Self-service ordering',
                  style: TextStyle(color: ColorManager.kTextColor),
                ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => showKioskLanguageSheet(context),
          icon: const Icon(Icons.language_rounded, size: 23),
          label: compact
              ? const SizedBox.shrink()
              : Text(kioskLanguageLabel(LocalizationService.locale)),
          style: OutlinedButton.styleFrom(
            foregroundColor: ColorManager.kTitleTextColor,
            minimumSize: Size(compact ? 56 : 132, 56),
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFDCE5F0)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _LandscapeWelcome extends StatelessWidget {
  final String storeName;
  final List<GetProduct> products;
  final VoidCallback onStart;

  const _LandscapeWelcome({
    required this.storeName,
    required this.products,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.only(left: 28, right: 42),
                  child: _WelcomeMessage(
                    storeName: storeName,
                    onStart: onStart,
                    centered: false,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: _ProductShowcase(products: products),
        ),
      ],
    );
  }
}

class _PortraitWelcome extends StatelessWidget {
  final String storeName;
  final List<GetProduct> products;
  final VoidCallback onStart;

  const _PortraitWelcome({
    required this.storeName,
    required this.products,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showcaseHeight =
            (constraints.maxHeight * 0.37).clamp(220.0, 360.0);
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: showcaseHeight,
                  child: _ProductShowcase(products: products),
                ),
                const SizedBox(height: 28),
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
    final height = MediaQuery.sizeOf(context).height;
    final condensed = height < 720;
    final titleSize = width < 680
        ? 38.0
        : condensed
            ? 44.0
            : 58.0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFDCE8F7)),
          ),
          child: const Text(
            'ORDER HERE',
            style: TextStyle(
              color: ColorManager.kPrimaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        SizedBox(height: condensed ? 12 : 18),
        Text(
          'Welcome to\n$storeName',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: ColorManager.kTitleTextColor,
            fontSize: titleSize,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
        ),
        SizedBox(height: condensed ? 10 : 16),
        Text(
          'Browse products, customise your choices, and pay securely.',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            color: ColorManager.kTextColor,
            fontSize: condensed ? 16 : 18,
            height: 1.5,
          ),
        ),
        SizedBox(height: condensed ? 18 : 28),
        SizedBox(
          width: centered ? double.infinity : 340,
          height: condensed ? 60 : 70,
          child: FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.arrow_forward_rounded, size: 27),
            label: const Text(
              'Start order',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
          ),
        ),
        SizedBox(height: condensed ? 8 : 13),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.touch_app_outlined,
                size: 18, color: ColorManager.kGreyColor),
            SizedBox(width: 7),
            Text(
              'Tap to begin',
              style: TextStyle(color: ColorManager.kGreyColor),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProductShowcase extends StatelessWidget {
  final List<GetProduct> products;

  const _ProductShowcase({required this.products});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 660),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: products.isEmpty
          ? const _ShowcaseFallback()
          : Row(
              children: [
                Expanded(
                  flex: 6,
                  child: _ProductTile(
                    product: products.first,
                    prominent: true,
                  ),
                ),
                if (products.length > 1) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(child: _ProductTile(product: products[1])),
                        if (products.length > 2) ...[
                          const SizedBox(height: 14),
                          Expanded(child: _ProductTile(product: products[2])),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final GetProduct product;
  final bool prominent;

  const _ProductTile({required this.product, this.prominent = false});

  @override
  Widget build(BuildContext context) {
    final imageUrl = resolveMarketProductImageUrl(product);
    final name = product.localizedName?.trim().isNotEmpty == true
        ? product.localizedName!.trim()
        : product.productName?.trim() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: const Color(0xFFF1F5FA),
            child: imageUrl == null
                ? const Icon(
                    Icons.inventory_2_outlined,
                    color: ColorManager.kGreyColor,
                    size: 58,
                  )
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.inventory_2_outlined,
                      color: ColorManager.kGreyColor,
                      size: 58,
                    ),
                  ),
          ),
          if (name.isNotEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: prominent ? 11 : 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ColorManager.kTitleTextColor,
                    fontSize: prominent ? 16 : 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShowcaseFallback extends StatelessWidget {
  const _ShowcaseFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_bag_outlined,
              size: 70, color: ColorManager.kPrimaryColor),
          SizedBox(height: 14),
          Text(
            'Browse our products',
            style: TextStyle(
              color: ColorManager.kTitleTextColor,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
          colors: [Color(0xFFF8FBFF), Color(0xFFEAF3FF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -130,
            top: -150,
            child: _Glow(size: 410, opacity: 0.10),
          ),
          Positioned(
            left: -160,
            bottom: -190,
            child: _Glow(size: 470, opacity: 0.07),
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

List<GetProduct> _featuredProducts(List<GetProduct> catalogue) {
  final featured = <GetProduct>[];
  for (final product in catalogue) {
    if (resolveMarketProductImageUrl(product) == null) continue;
    featured.add(product);
    if (featured.length == 3) return featured;
  }
  for (final product in catalogue) {
    if (featured.contains(product)) continue;
    featured.add(product);
    if (featured.length == 3) break;
  }
  return featured;
}
