import 'package:pdf/widgets.dart' as pw;

import 'receipt_layout.dart';
import 'receipt_layout_params.dart';
import 'standard_receipt_layout.dart';

/// Shared entry-point delegate for legacy layout classes.
///
/// The legacy source files are retained for historical visual references and
/// custom integrations, but their public entry points must not silently use
/// the old, partial language/visibility implementations.  They call this
/// delegate before their retained implementation, so direct construction is
/// contract-safe in the same way as factory construction.
class ReceiptContractDelegate {
  ReceiptContractDelegate._();

  // Create a renderer per call. StandardReceiptLayout keeps the normalized
  // language mode for the duration of a print, so a singleton would allow
  // concurrent prints to overwrite one another's mode.

  /// Kept as a runtime getter (rather than a compile-time constant) so the
  /// historical implementations remain reachable for source-level reference
  /// and future visual migrations without affecting current output.
  static bool get enabled => true;

  static Future<void> printThermal(ReceiptLayoutParams params) =>
      StandardReceiptLayout().printThermal(params);

  static Future<pw.Document> buildPdf(ReceiptLayoutParams params) =>
      StandardReceiptLayout().buildPdf(params);

  static Future<void> printThermalNative(ReceiptLayoutParams params) =>
      StandardReceiptLayout().printThermalNative(params);
}

/// Thermal-layout adapter used for legacy theme identifiers.
///
/// The project contains several historical receipt implementations that grew
/// their own language and visibility rules.  Those implementations are kept
/// in the repository for backwards compatibility and visual reference, but
/// the production factory routes them through this adapter so every selected
/// theme uses the same normalized 61-key contract, three language modes, data
/// sources, section order, and strict visibility semantics.
///
/// A theme can later provide a distinct visual renderer by replacing its
/// factory entry without changing the configuration contract.
class ContractReceiptLayout implements ReceiptLayout {
  final String _layoutId;
  final String _displayName;
  final StandardReceiptLayout _renderer;

  ContractReceiptLayout({
    required String layoutId,
    required String displayName,
  })  : _layoutId = layoutId,
        _displayName = displayName,
        _renderer = StandardReceiptLayout();

  @override
  String get layoutId => _layoutId;

  @override
  String get displayName => _displayName;

  @override
  Future<void> printThermal(ReceiptLayoutParams params) =>
      _renderer.printThermal(params);

  @override
  Future<pw.Document> buildPdf(ReceiptLayoutParams params) =>
      _renderer.buildPdf(params);

  @override
  Future<void> printThermalNative(ReceiptLayoutParams params) =>
      _renderer.printThermalNative(params);
}
