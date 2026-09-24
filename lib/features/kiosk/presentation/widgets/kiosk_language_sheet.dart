import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/localization_service.dart';

Future<void> showKioskLanguageSheet(BuildContext context) async {
  final locale = await showModalBottomSheet<Locale>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _KioskLanguageSheet(),
  );
  if (locale == null || !context.mounted) return;
  await LocalizationService.updateLocale(locale);
  Get.updateLocale(locale);
}

String kioskLanguageLabel(Locale locale) {
  switch (locale.languageCode) {
    case 'ar':
      return 'العربية';
    case 'ml':
      return 'മലയാളം';
    default:
      return 'English';
  }
}

class _KioskLanguageSheet extends StatelessWidget {
  const _KioskLanguageSheet();

  @override
  Widget build(BuildContext context) {
    final currentCode = LocalizationService.locale.languageCode;
    final compact = MediaQuery.sizeOf(context).width < 520;

    return SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 26,
              14,
              compact ? 18 : 26,
              24,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCE2EC),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose your language',
                        style: TextStyle(
                          color: ColorManager.kTitleTextColor,
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select the language you would like to use.',
                  style: TextStyle(color: ColorManager.kTextColor),
                ),
                const SizedBox(height: 20),
                for (final locale in LocalizationService.supportedLocales) ...[
                  _LanguageTile(
                    locale: locale,
                    selected: locale.languageCode == currentCode,
                  ),
                  if (locale != LocalizationService.supportedLocales.last)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final Locale locale;
  final bool selected;

  const _LanguageTile({required this.locale, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? ColorManager.kPrimaryWithOpacity10
          : const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(locale),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? ColorManager.kPrimaryColor
                  : const Color(0xFFE2E7F0),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  locale.languageCode.toUpperCase(),
                  style: const TextStyle(
                    color: ColorManager.kPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  kioskLanguageLabel(locale),
                  style: const TextStyle(
                    color: ColorManager.kTitleTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_off_rounded,
                color: selected
                    ? ColorManager.kPrimaryColor
                    : ColorManager.kGreyColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
