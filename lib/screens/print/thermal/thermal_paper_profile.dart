import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// The paper profiles understood by the receipt thermal pipeline.
///
/// `esc_pos_utils_plus` 2.0.4 only exposes 58, 72 and 80 mm paper sizes.  It
/// does not expose a public constructor for a custom [PaperSize].  A 112 mm
/// receipt is therefore rendered as a bitmap at its real 832-dot width and
/// sent through the package's image command.  The package's 80 mm profile is
/// used only for commands that need a paper profile (alignment/barcode/feed),
/// never to resize the bitmap.
///
/// Keeping that limitation explicit here prevents a future caller from
/// accidentally treating 112 mm as an ordinary 80 mm text receipt.
class ThermalPaperProfile {
  const ThermalPaperProfile._({
    required this.id,
    required this.rasterWidthPx,
    required this.escPosPaperSize,
    required this.supportsNativeText,
    required this.transport,
  });

  static const mm58 = ThermalPaperProfile._(
    id: '58mm',
    rasterWidthPx: 384,
    escPosPaperSize: PaperSize.mm58,
    supportsNativeText: true,
    transport: ThermalTransport.nativeOrRaster,
  );

  static const mm80 = ThermalPaperProfile._(
    id: '80mm',
    rasterWidthPx: 576,
    escPosPaperSize: PaperSize.mm80,
    supportsNativeText: true,
    transport: ThermalTransport.nativeOrRaster,
  );

  static const mm112 = ThermalPaperProfile._(
    id: '112mm',
    rasterWidthPx: 832,
    // This is the closest public profile in esc_pos_utils_plus.  It must not
    // be used to size a bitmap; [rasterWidthPx] is the authoritative width.
    escPosPaperSize: PaperSize.mm80,
    supportsNativeText: false,
    transport: ThermalTransport.rasterOnly,
  );

  /// The value persisted by the printer settings screen.
  final String id;

  /// The actual bitmap width used by the receipt renderer.
  final int rasterWidthPx;

  /// The closest public `esc_pos_utils_plus` profile used for non-raster
  /// commands. For 112 mm this is necessarily `PaperSize.mm80` because the
  /// dependency has no public custom-width profile.
  final PaperSize escPosPaperSize;

  /// Whether native text commands can represent this paper width safely.
  /// 112 mm is deliberately raster-only.
  final bool supportsNativeText;

  final ThermalTransport transport;

  bool get is58mm => identical(this, mm58);
  bool get is80mm => identical(this, mm80);
  bool get is112mm => identical(this, mm112);
  bool get isRasterOnly => transport == ThermalTransport.rasterOnly;

  /// Normalize a persisted paper-size value without changing the historical
  /// 58/80 mm fallback behavior. Unknown values continue to use 80 mm, but
  /// callers can inspect [id] and will never mistake that fallback for 112 mm.
  static ThermalPaperProfile fromSelection(String? value) {
    switch (value?.trim().toLowerCase()) {
      case '58mm':
      case '58 mm':
        return mm58;
      case '112mm':
      case '112 mm':
        return mm112;
      case '80mm':
      case '80 mm':
      default:
        return mm80;
    }
  }

  /// All receipt sizes currently offered by the thermal settings UI.
  static const List<ThermalPaperProfile> thermalProfiles =
      <ThermalPaperProfile>[
    mm112,
    mm80,
    mm58,
  ];

  /// Create an ESC/POS generator for this profile.
  ///
  /// For 112 mm the generator is intentionally only used for commands such
  /// as feed/cut/barcode. Image commands use the source bitmap's 832-dot
  /// width, which `Generator.image` preserves.
  Generator createGenerator(CapabilityProfile capabilityProfile) {
    return Generator(escPosPaperSize, capabilityProfile);
  }

  /// Fail loudly if a caller tries to use native text for 112 mm.
  void requireNativeTextSupport() {
    if (!supportsNativeText) {
      throw UnsupportedError(
        '112mm thermal receipts require raster/image printing. '
        'esc_pos_utils_plus 2.0.4 has no custom 112mm PaperSize profile.',
      );
    }
  }

  @override
  String toString() =>
      '$id (${rasterWidthPx}px, ${transport.name}, escPos=${escPosPaperSize.value})';
}

enum ThermalTransport {
  nativeOrRaster,
  rasterOnly,
}
