/// Build-time branding for white-label Windows builds.
///
/// Values come from `--dart-define-from-file=brands/<id>/brand.json`, which
/// `scripts/build_brand.ps1` passes together with the matching native settings.
/// The defaults are the CloudPOS brand, so a plain `flutter run` needs no
/// flags and tests see CloudPOS.
abstract final class BrandConfig {
  static const String id =
      String.fromEnvironment('BRAND_ID', defaultValue: 'cloudpos');

  /// Used inside sentences: "Restart CloudPOS".
  static const String name =
      String.fromEnvironment('BRAND_NAME', defaultValue: 'CloudPOS');

  /// Window and task-switcher title.
  static const String title =
      String.fromEnvironment('BRAND_TITLE', defaultValue: 'CLOUDPOS');

  /// Wide logo (side menu, kiosk).
  static const String logoAsset = String.fromEnvironment('BRAND_LOGO_ASSET',
      defaultValue: 'assets/logo/cloudposlogo.png');

  /// Square icon (startup screen).
  static const String iconAsset = String.fromEnvironment('BRAND_ICON_ASSET',
      defaultValue: 'assets/logo/cloudpos-icon.png');

  /// Installed executable name, as shown in Task Manager's Details tab.
  static const String exeName =
      String.fromEnvironment('BRAND_EXE_NAME', defaultValue: 'cloudpos.exe');

  /// Swaps the CloudPOS name in built-in copy for this brand's name.
  static String apply(String text) => id == 'cloudpos'
      ? text
      : text
          .replaceAll('cloudpos.exe', exeName)
          .replaceAll('CLOUDPOS', title)
          .replaceAll('CloudPOS', name);
}
