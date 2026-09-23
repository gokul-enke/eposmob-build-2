import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/features/weigh_machine/domain/plu_csv.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PluExportService {
  PluExportService._();
  static final instance = PluExportService._();

  LocalProductProvider? _catalog;
  Timer? _pending;
  bool _writing = false;

  /// Bumped by [discardFile]; an automatic write started before a discard
  /// checks it and gives up instead of recreating the deleted file.
  int _generation = 0;

  /// The automatic write in progress, awaited by [discardFile].
  Future<void>? _inFlight;

  /// Set by [discardFile]: no automatic writes until the catalog has been
  /// cleared and reloaded, so the old catalog is never written back.
  bool _held = false;
  bool _clearedSeen = false;
  bool _reloadStarted = false;

  /// Quiet time before an automatic write, so a burst of changes writes once.
  @visibleForTesting
  Duration autoWriteDelay = const Duration(seconds: 2);

  /// Unbinds and forgets all in-memory state between tests.
  @visibleForTesting
  void resetForTest() {
    _catalog?.removeListener(_catalogChanged);
    _catalog = null;
    _pending?.cancel();
    _inFlight = null;
    _writing = false;
    _held = false;
    _clearedSeen = false;
    _reloadStarted = false;
    autoWriteDelay = const Duration(seconds: 2);
  }

  void bind(LocalProductProvider catalog) {
    if (identical(_catalog, catalog)) return;
    _catalog?.removeListener(_catalogChanged);
    _catalog = catalog;
    catalog.addListener(_catalogChanged);
    _catalogChanged();
  }

  Future<String> _prefix() async {
    final prefs = await SharedPreferences.getInstance();
    final tenant = prefs.getString('api_key') ?? 'local';
    final store = prefs.getInt('active_store_id')?.toString() ?? 'default';
    return 'plu_export_${tenant}_$store';
  }

  Future<bool> autoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${await _prefix()}_auto') ?? false;
  }

  Future<void> setAutoEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${await _prefix()}_auto', enabled);
    if (enabled) _catalogChanged();
  }

  /// Products ticked on the page, used only by Excel export. PLU.csv does
  /// not read this; it always holds every product with an SKU. The key is
  /// new so ticks from the old "machine selection" do not carry over.
  Future<Set<int>?> selectedProductIds() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('${await _prefix()}_excel_ticks');
    return values?.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> setSelectedProductIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '${await _prefix()}_excel_ticks',
      ids.map((id) => id.toString()).toList(),
    );
  }

  /// Default save folder, inside the app's own `Documents/epos` folder that
  /// printing and other exports already use.
  static const defaultFolder = ['epos', 'PLU'];

  @visibleForTesting
  Future<Directory> Function() documentsDirectory =
      getApplicationDocumentsDirectory;

  /// The user's chosen folder, or `Documents/epos/PLU`. The default folder is
  /// created when missing so the first download never fails on it.
  Future<String> directoryPath() => _directoryPath(create: true);

  Future<String> _directoryPath({required bool create}) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('${await _prefix()}_directory');
    if (saved != null && saved.isNotEmpty) return saved;
    final documents = await documentsDirectory();
    final directory = Directory(
        [documents.path, ...defaultFolder].join(Platform.pathSeparator));
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  /// Deletes the active store's PLU.csv (and any leftover `.tmp`).
  ///
  /// PLU.csv is a copy of the product catalog, so it is discarded wherever
  /// the catalog is: on Reset API key, Clear local storage and a store
  /// switch. This keeps another tenant's or store's items off the scale. It
  /// is rebuilt from the API after the next login and sync. Logout keeps it:
  /// the same store usually logs back in.
  ///
  /// Call it before the active store or saved settings change, so the right
  /// folder is found, and before the catalog is cleared: automatic writes
  /// stay paused until the catalog is cleared and a fresh load finishes.
  /// It never throws; a failure must not block a reset.
  Future<void> discardFile() async {
    _generation++;
    _pending?.cancel();
    _held = true;
    _clearedSeen = false;
    _reloadStarted = false;
    try {
      // Let a write that already started finish before deleting its file.
      await _inFlight;
    } catch (_) {}
    try {
      final folder = await _directoryPath(create: false);
      for (final name in [PluCsv.fileName, '${PluCsv.fileName}.tmp']) {
        final file = File('$folder${Platform.pathSeparator}$name');
        if (await file.exists()) await file.delete();
      }
    } catch (error) {
      debugPrint('Could not remove PLU.csv: $error');
    }
  }

  /// Whether the user has picked a folder instead of using the default.
  Future<bool> usesCustomDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('${await _prefix()}_directory');
    return saved != null && saved.isNotEmpty;
  }

  /// Forgets the chosen folder so files go to `Documents/epos/PLU` again.
  Future<void> resetDirectoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${await _prefix()}_directory');
    if (await autoEnabled()) _catalogChanged();
  }

  Future<void> setDirectoryPath(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      throw const FileSystemException('Selected folder is unavailable');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${await _prefix()}_directory', path);
    if (await autoEnabled()) _catalogChanged();
  }

  /// Writes PLU.csv. Products without an SKU are never written, whatever
  /// the caller passes; see [PluCsv.isWeighted].
  Future<File> export(Iterable<GetProduct> products) async {
    final items = PluCsv.weighted(products);
    if (items.isEmpty) {
      throw StateError('Select at least one product with an SKU.');
    }
    final directory = Directory(await directoryPath());
    if (!await directory.exists()) {
      throw FileSystemException('Save folder is unavailable', directory.path);
    }
    final output =
        File('${directory.path}${Platform.pathSeparator}${PluCsv.fileName}');
    final content = PluCsv.build(items);
    final temporary = File('${output.path}.tmp');
    try {
      await temporary.writeAsString(content, flush: true);
      await temporary.copy(output.path);
      return output;
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  void _catalogChanged() {
    _pending?.cancel();
    final catalog = _catalog;
    if (catalog == null) return;
    if (_held) {
      // After a discard, wait for the old catalog to be cleared and a fresh
      // one to finish loading. Anything earlier is the old store or tenant.
      if (catalog.products.isEmpty && !catalog.isLoading) _clearedSeen = true;
      if (catalog.isLoading && _clearedSeen) _reloadStarted = true;
      if (catalog.isLoading || !_reloadStarted) return;
      _held = false;
      _clearedSeen = false;
      _reloadStarted = false;
    }
    if (catalog.isLoading || !catalog.isHydrated) return;
    final generation = _generation;
    _pending = Timer(autoWriteDelay, () {
      if (_writing) {
        _catalogChanged();
        return;
      }
      _inFlight = _autoWrite(catalog, generation);
    });
  }

  Future<void> _autoWrite(LocalProductProvider catalog, int generation) async {
    if (!await autoEnabled()) return;
    // Every SKU product; ticks on the page are for Excel only.
    final items = PluCsv.weighted(catalog.products);
    if (items.isEmpty) return;
    _writing = true;
    try {
      final path = await directoryPath();
      final file = File('$path${Platform.pathSeparator}${PluCsv.fileName}');
      final next = PluCsv.build(items);
      if (generation != _generation) return; // discarded meanwhile
      if (!await file.exists() || await file.readAsString() != next) {
        await export(items);
      }
    } catch (error) {
      debugPrint('Automatic PLU export failed: $error');
    } finally {
      _writing = false;
    }
  }
}
