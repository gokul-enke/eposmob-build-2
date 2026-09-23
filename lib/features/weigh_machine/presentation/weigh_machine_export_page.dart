import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pos_machine/features/weigh_machine/data/product_excel_export_service.dart';
import 'package:pos_machine/features/weigh_machine/data/plu_export_service.dart';
import 'package:pos_machine/features/weigh_machine/domain/plu_csv.dart';
import 'package:pos_machine/features/weigh_machine/presentation/widgets/plu_file_panel.dart';
import 'package:pos_machine/features/weigh_machine/presentation/widgets/plu_product_list.dart';
import 'package:pos_machine/features/weigh_machine/presentation/widgets/weigh_ui.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:provider/provider.dart';

class WeighMachineExportPage extends StatefulWidget {
  const WeighMachineExportPage({super.key});

  @override
  State<WeighMachineExportPage> createState() => _WeighMachineExportPageState();
}

class _WeighMachineExportPageState extends State<WeighMachineExportPage> {
  static const _wideLayout = 1000.0;

  final _search = TextEditingController();
  Set<int>? _selected;
  String? _category;

  /// Scale items first; All is one tap away. Reset returns here.
  static const _defaultView = PluProductView.weighted;
  PluProductView _view = _defaultView;
  String? _destination;
  bool _customFolder = false;
  bool _autoEnabled = false;
  PluTask? _running;
  PluLastSave? _lastSave;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final service = PluExportService.instance;
    final selected = await service.selectedProductIds();
    final destination = await service.directoryPath();
    final customFolder = await service.usesCustomDirectory();
    final autoEnabled = await service.autoEnabled();
    if (mounted) {
      setState(() {
        _selected = selected;
        _destination = destination;
        _customFolder = customFolder;
        _autoEnabled = autoEnabled;
      });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters => _search.text.trim().isNotEmpty || _category != null;

  /// Products matching search and category, before the All/Selected/Weighted
  /// view is applied. The view chips count from this list.
  List<GetProduct> _filtered(List<GetProduct> products) {
    final query = _search.text.trim().toLowerCase();
    return products.where((product) {
      if (_category != null && product.category?.name != _category) {
        return false;
      }
      if (query.isEmpty) return true;
      return (product.productName ?? '').toLowerCase().contains(query) ||
          (product.barcode ?? '').toLowerCase().contains(query);
    }).toList(growable: false);
  }

  List<GetProduct> _inView(List<GetProduct> filtered) => switch (_view) {
        PluProductView.all => filtered,
        PluProductView.selected =>
          filtered.where(_isSelected).toList(growable: false),
        PluProductView.weighted => PluCsv.weighted(filtered),
      };

  /// Ticks drive Excel's "Only ticked products" option. Any product can be
  /// ticked; PLU.csv ignores ticks and always holds every SKU product.
  bool _isSelected(GetProduct product) =>
      _selected?.contains(product.productId) ?? false;

  Set<int> _ensureSelection() => _selected ??= <int>{};

  void _persistSelection() {
    unawaited(PluExportService.instance.setSelectedProductIds(_selected!));
  }

  void _updateSelection(GetProduct product, bool selected) {
    setState(() {
      final ids = _ensureSelection();
      if (selected) {
        if (product.productId != null) ids.add(product.productId!);
      } else {
        ids.remove(product.productId);
      }
    });
    _persistSelection();
  }

  void _setShown(List<GetProduct> shown, bool select) {
    final ids = shown.map((p) => p.productId).whereType<int>().toList();
    if (select) {
      setState(() => _ensureSelection().addAll(ids));
      _persistSelection();
      return;
    }
    _changeWithUndo(
      (selection) => selection.removeAll(ids),
      'Unticked ${WeighFormat.products(ids.length)}',
    );
  }

  void _clearSelection(List<GetProduct> all) {
    final count = all.where(_isSelected).length;
    _changeWithUndo(
      (selection) => selection.clear(),
      'Unticked ${WeighFormat.products(count)}',
    );
  }

  void _changeWithUndo(void Function(Set<int>) change, String message) {
    final before = Set<int>.of(_ensureSelection());
    setState(() => change(_selected!));
    _persistSelection();
    showScaffold(
      context: context,
      message: message,
      actionLabel: 'Undo',
      onAction: () {
        if (!mounted) return;
        setState(() => _selected = before);
        _persistSelection();
      },
    );
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    if (error) {
      showScaffoldError(context: context, message: text);
    } else {
      showScaffold(context: context, message: text);
    }
  }

  Future<void> _download({bool sync = false}) async {
    if (_running != null) return;
    setState(() => _running = sync ? PluTask.sync : PluTask.download);
    try {
      final catalog = context.read<LocalProductProvider>();
      await catalog.hydrated;
      if (sync) {
        await catalog.fetchProductsFromAPI(
          refresh: true,
          throwOnError: true,
        );
      }
      // Every SKU product, ticked or not.
      final items = PluCsv.weighted(catalog.products);
      if (items.isEmpty) {
        _message('No products have an SKU yet, so there is nothing for '
            'the weigh machine.');
        return;
      }
      final file = await PluExportService.instance.export(items);
      if (!mounted) return;
      setState(() => _lastSave = PluLastSave(
            at: DateTime.now(),
            count: items.length,
            path: file.path,
          ));
      _message('Saved ${WeighFormat.products(items.length)} to ${file.path}');
    } catch (error) {
      _message('Could not create PLU.csv: $error', error: true);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<void> _syncCatalog() async {
    if (_running != null) return;
    setState(() => _running = PluTask.sync);
    try {
      await context.read<LocalProductProvider>().fetchProductsFromAPI(
            refresh: true,
            throwOnError: true,
          );
    } catch (error) {
      _message('Could not sync products: $error', error: true);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<void> _chooseFolder() async {
    final chosen = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose PLU.csv save folder',
    );
    if (chosen == null) return;
    try {
      await PluExportService.instance.setDirectoryPath(chosen);
      if (mounted) {
        setState(() {
          _destination = chosen;
          _customFolder = true;
        });
      }
    } catch (error) {
      _message('Could not use folder: $error', error: true);
    }
  }

  Future<void> _useDefaultFolder() async {
    try {
      final service = PluExportService.instance;
      await service.resetDirectoryPath();
      final path = await service.directoryPath();
      if (!mounted) return;
      setState(() {
        _destination = path;
        _customFolder = false;
      });
      _message('PLU.csv will be saved to $path');
    } catch (error) {
      _message('Could not use the default folder: $error', error: true);
    }
  }

  Future<void> _setAuto(bool enabled) async {
    setState(() => _autoEnabled = enabled);
    await PluExportService.instance.setAutoEnabled(enabled);
    _message(enabled
        ? 'PLU.csv will update automatically.'
        : 'Automatic updates turned off.');
  }

  Future<void> _exportExcel() async {
    final fields = ProductExcelField.defaults.toSet();
    var selectedOnly = false;
    final choice = await showDialog<(List<ProductExcelField>, bool)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Export products to Excel'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Columns',
                          style: TextStyle(
                              color: WeighUiColors.heading,
                              fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      key: const ValueKey('excel_toggle_all'),
                      style: TextButton.styleFrom(
                        foregroundColor: ColorManager.kPrimaryColor,
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => update(() {
                        if (fields.length == ProductExcelField.values.length) {
                          fields
                            ..clear()
                            ..addAll(ProductExcelField.defaults);
                        } else {
                          fields.addAll(ProductExcelField.values);
                        }
                      }),
                      child: Text(
                          fields.length == ProductExcelField.values.length
                              ? 'Name only'
                              : 'Select all'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final field in ProductExcelField.values)
                      FilterChip(
                        key: ValueKey('excel_field_${field.name}'),
                        label: Text(field.label),
                        selected: fields.contains(field),
                        backgroundColor: Colors.white,
                        selectedColor: WeighUiColors.softBlue,
                        checkmarkColor: ColorManager.kPrimaryColor,
                        side: const BorderSide(color: WeighUiColors.border),
                        onSelected: (selected) => update(() {
                          if (selected) {
                            fields.add(field);
                          } else {
                            fields.remove(field);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  key: const ValueKey('excel_selected_only'),
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: ColorManager.kPrimaryColor,
                  activeTrackColor:
                      ColorManager.kPrimaryColor.withValues(alpha: 0.3),
                  title: const Text('Only ticked products'),
                  subtitle: const Text('Otherwise export every product '
                      'matching the current search and category.'),
                  value: selectedOnly,
                  onChanged: (value) => update(() => selectedOnly = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: ColorManager.kPrimaryColor),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              key: const ValueKey('excel_confirm'),
              style: weighPrimaryButtonStyle(),
              onPressed: fields.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, (
                        [
                          for (final field in ProductExcelField.values)
                            if (fields.contains(field)) field
                        ],
                        selectedOnly,
                      )),
              child: const Text('Export Excel'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _running = PluTask.excel);
    try {
      final catalog = context.read<LocalProductProvider>();
      await catalog.hydrated;
      final matching = _filtered(catalog.products);
      final products = choice.$2
          ? matching.where(_isSelected).toList(growable: false)
          : matching;
      final file = await ProductExcelExportService.export(products, choice.$1);
      _message(
          'Saved ${WeighFormat.products(products.length)} to ${file.path}');
    } catch (error) {
      _message('Could not export Excel: $error', error: true);
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  void _resetFilters() {
    _search.clear();
    setState(() {
      _category = null;
      _view = _defaultView;
    });
  }

  Widget _emptyState({required bool catalogEmpty}) {
    if (catalogEmpty) {
      return WeighEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products yet',
        message: 'Sync the catalog to load products from CloudPOS.',
        actionLabel: 'Sync catalog',
        onAction: _running == null ? _syncCatalog : null,
      );
    }
    if (!_hasFilters && _view == PluProductView.selected) {
      return WeighEmptyState(
        icon: Icons.checklist_rounded,
        title: 'Nothing selected yet',
        message: 'Tick products in the full list to export them to Excel.',
        actionLabel: 'Show all products',
        onAction: () => setState(() => _view = PluProductView.all),
      );
    }
    if (!_hasFilters && _view == PluProductView.weighted) {
      return WeighEmptyState(
        icon: Icons.scale_outlined,
        title: 'No weighted products',
        message: 'Only products with an SKU can go on the weigh machine. '
            'Ask your back office to add an SKU to the items the scale '
            'sells, then sync.',
        actionLabel: 'Show all products',
        onAction: () => setState(() => _view = PluProductView.all),
      );
    }
    return WeighEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No matching products',
      message: 'Try another name, barcode or category.',
      actionLabel: 'Reset filters',
      onAction: _resetFilters,
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<LocalProductProvider>();
    final all = catalog.products;
    final filtered = _filtered(all);
    final visible = _inView(filtered);
    final categories = all
        .map((p) => p.category?.name)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final selectedCount = all.where(_isSelected).length;
    // What PLU.csv will hold: every SKU product, regardless of ticks.
    final pluCount = PluCsv.weighted(all).length;
    final counts = PluViewCounts(
      all: filtered.length,
      selected: filtered.where(_isSelected).length,
      weighted: PluCsv.weighted(filtered).length,
    );
    final shownSelected = _view == PluProductView.selected
        ? visible.length
        : visible.where(_isSelected).length;
    final bool? allShownState = shownSelected == 0
        ? false
        : shownSelected == visible.length
            ? true
            : null;

    void toggle(GetProduct product, bool value) =>
        _updateSelection(product, value);
    void toggleAllShown() => _setShown(visible, allShownState != true);

    final empty = _emptyState(catalogEmpty: all.isEmpty);

    final filters = PluProductFilters(
      search: _search,
      onSearchChanged: () => setState(() {}),
      categories: categories,
      category: _category,
      onCategoryChanged: (value) => setState(() => _category = value),
      view: _view,
      counts: counts,
      onViewChanged: (value) => setState(() => _view = value),
      onReset: _hasFilters || _view != _defaultView ? _resetFilters : null,
    );

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= _wideLayout;

      final header = _PageHeader(
        compact: constraints.maxWidth < 560,
        exporting: _running == PluTask.excel,
        onExportExcel: _running == null ? _exportExcel : null,
      );

      final filePanel = PluFilePanel(
        productCount: pluCount,
        destination: _destination,
        autoEnabled: _autoEnabled,
        running: _running,
        lastSave: _lastSave,
        onDownload: _download,
        onSyncDownload: () => _download(sync: true),
        onChooseFolder: _chooseFolder,
        onUseDefaultFolder: _customFolder ? _useDefaultFolder : null,
        onAutoChanged: _setAuto,
        showDownload: wide,
        folderHint: Platform.isAndroid || Platform.isIOS
            ? 'Choose a folder your weigh machine can read before turning on '
                'automatic updates.'
            : null,
      );

      final resultsLine = _ResultsLine(
        shown: visible.length,
        total: all.length,
        allShownState: allShownState,
        onToggleAllShown: visible.isEmpty ? null : toggleAllShown,
        showSelectAll: !wide,
      );

      if (wide) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1440),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      header,
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: WeighSurface(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 16, 16, 4),
                                      child: filters,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: resultsLine,
                                    ),
                                    Expanded(
                                      child: PluProductTable(
                                        products: visible,
                                        isSelected: _isSelected,
                                        onToggle: toggle,
                                        allShownState: allShownState,
                                        onToggleAllShown: visible.isEmpty
                                            ? null
                                            : toggleAllShown,
                                        empty: empty,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 340,
                              child: SingleChildScrollView(child: filePanel),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      final gutter = constraints.maxWidth < 560 ? 12.0 : 18.0;
      return Scaffold(
        backgroundColor: Colors.white,
        bottomNavigationBar: PluSelectionBar(
          productCount: pluCount,
          tickedCount: selectedCount,
          onClear: selectedCount == 0 ? null : () => _clearSelection(all),
          download: PluDownloadButton(
            enabled: pluCount > 0 && _running == null,
            running: _running == PluTask.download,
            onPressed: _download,
            label: 'Download',
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, gutter, gutter, 0),
                sliver: SliverList.list(children: [
                  header,
                  const SizedBox(height: 14),
                  filePanel,
                  const SizedBox(height: 14),
                  WeighSurface(
                      padding: const EdgeInsets.all(14), child: filters),
                  const SizedBox(height: 6),
                  resultsLine,
                ]),
              ),
              if (visible.isEmpty)
                SliverToBoxAdapter(child: empty)
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                  sliver: SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final product = visible[index];
                      return PluProductCard(
                        product: product,
                        selected: _isSelected(product),
                        onToggle: toggle,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.compact,
    required this.exporting,
    required this.onExportExcel,
  });

  final bool compact;
  final bool exporting;
  final VoidCallback? onExportExcel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        WeighIconTile(icon: Icons.scale_outlined, size: compact ? 40 : 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Weigh machine',
                style: TextStyle(
                  color: WeighUiColors.heading,
                  fontSize: compact ? 20 : 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 3),
                const Text(
                  'Products with an SKU are saved to PLU.csv for your scale.',
                  style: TextStyle(color: WeighUiColors.muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: 'Export product details to an Excel sheet',
          child: OutlinedButton.icon(
            key: const ValueKey('product_excel_export'),
            onPressed: onExportExcel,
            icon: exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_view_outlined, size: 18),
            label: Text(compact ? 'Excel' : 'Export Excel'),
            style: weighSecondaryButtonStyle(),
          ),
        ),
      ],
    );
  }
}

class _ResultsLine extends StatelessWidget {
  const _ResultsLine({
    required this.shown,
    required this.total,
    required this.allShownState,
    required this.onToggleAllShown,
    required this.showSelectAll,
  });

  final int shown;
  final int total;
  final bool? allShownState;
  final VoidCallback? onToggleAllShown;

  /// The desktop table has a header checkbox instead.
  final bool showSelectAll;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextButton.styleFrom(
      foregroundColor: ColorManager.kPrimaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    );
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: Text(
              shown == total
                  ? WeighFormat.products(total)
                  : 'Showing ${WeighFormat.count(shown)} of '
                      '${WeighFormat.count(total)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: WeighUiColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (showSelectAll && onToggleAllShown != null)
            TextButton(
              key: const ValueKey('plu_select_all_shown'),
              style: linkStyle,
              onPressed: onToggleAllShown,
              child: Text(
                  allShownState == true ? 'Deselect shown' : 'Select shown'),
            ),
        ],
      ),
    );
  }
}
