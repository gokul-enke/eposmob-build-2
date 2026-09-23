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

  Future<Set<int>?> selectedProductIds() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('${await _prefix()}_products');
    return values?.map(int.tryParse).whereType<int>().toSet();
  }

  Future<void> setSelectedProductIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '${await _prefix()}_products',
      ids.map((id) => id.toString()).toList(),
    );
    if (await autoEnabled()) _catalogChanged();
  }

  Future<String> directoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('${await _prefix()}_directory');
    if (saved != null && saved.isNotEmpty) return saved;
    final directory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    return directory.path;
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

  Future<File> export(Iterable<GetProduct> products) async {
    final items = products.toList(growable: false);
    if (items.isEmpty) {
      throw StateError('Select at least one product to export.');
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
    if (catalog == null || catalog.isLoading || !catalog.isHydrated) return;
    _pending = Timer(const Duration(seconds: 2), () async {
      if (_writing) {
        _catalogChanged();
        return;
      }
      if (!await autoEnabled()) return;
      final selected = await selectedProductIds();
      final items = selected == null
          ? PluCsv.weighted(catalog.products)
          : catalog.products
              .where((product) => selected.contains(product.productId))
              .toList(growable: false);
      if (items.isEmpty) return;
      _writing = true;
      try {
        final path = await directoryPath();
        final file = File('$path${Platform.pathSeparator}${PluCsv.fileName}');
        final next = PluCsv.build(items);
        if (!await file.exists() || await file.readAsString() != next) {
          await export(items);
        }
      } catch (error) {
        debugPrint('Automatic PLU export failed: $error');
      } finally {
        _writing = false;
      }
    });
  }
}
