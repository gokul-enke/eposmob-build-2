/// Fixed component sizes, so buttons and inputs line up on every platform
/// (desktop uses a compact visual density that would otherwise shrink some
/// controls but not others).
abstract final class AppSizes {
  /// Height of buttons, square icon buttons and filter inputs.
  static const double control = 44;

  /// Height of compact controls (table actions, pagination arrows).
  static const double compactControl = 36;
}
