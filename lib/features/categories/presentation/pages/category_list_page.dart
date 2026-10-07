import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/core/export/file_export_service.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/category_list_scope.dart';
import '../../data/category_list_source.dart';
import '../../domain/category_list_entry.dart';
import '../state/category_list_controller.dart';
import '../export/category_list_export.dart';
import '../navigation/category_navigation.dart';
import '../widgets/category_list_views.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage(
      {super.key, this.exportController, this.exportDirectory});
  final ExportController? exportController;
  final Directory? exportDirectory;
  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  late final CategoryProvider _provider;
  late final CategoryListController _controller;
  late final ExportController _export;
  late final bool _ownsExport;
  bool? _showFilters;
  bool _openingEdit = false;
  @override
  void initState() {
    super.initState();
    _provider = context.read<CategoryProvider>();
    _controller = CategoryListController(CategoryListSource(
        readEntries: () => _provider.allCategories
            .map((entry) => CategoryListEntry(
                id: entry.categoryId,
                name: entry.categoryName,
                slug: entry.categorySlug,
                translations: entry.translations))
            .toList(),
        ensureLoaded: () => _provider.ensureCategories(CategoryListScope.all),
        isBusy: () => _provider.isLoading,
        addListener: _provider.addListener,
        removeListener: _provider.removeListener));
    _ownsExport = widget.exportController == null;
    _export = widget.exportController ?? ExportController();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (!mounted) return;
    await _controller.load();
    if (mounted && _controller.error != null) {
      AppToast.error(context, 'category.load_failed'.tr);
    }
  }

  Future<void> _reset() async {
    _controller.reset();
    await _load();
  }

  Future<void> _edit(CategoryListEntry entry) async {
    if (_controller.loading || _openingEdit) return;
    setState(() => _openingEdit = true);
    try {
      _provider.setEditCategoryId(categoryId: entry.id ?? 1);
      await _provider.viewCategoryApi(categoryId: entry.id ?? 1);
      // The details are already fetched; a background load of another
      // category scope must not cancel the navigation the user asked for.
      if (mounted) CategoryNavigation.openEdit();
    } catch (_) {
      if (mounted) AppToast.error(context, 'category.open_failed'.tr);
    } finally {
      if (mounted) setState(() => _openingEdit = false);
    }
  }

  void _add() {
    if (!mounted || _controller.loading || _openingEdit) return;
    CategoryNavigation.openAdd();
  }

  Future<void> _exportRows() async {
    if (_controller.loading || _controller.error != null || _export.busy) {
      return;
    }
    _controller.flushSearch();
    final snapshot = List<CategoryListEntry>.unmodifiable(_controller.rows);
    if (snapshot.isEmpty) {
      AppToast.info(context, 'category.no_categories'.tr);
      return;
    }
    final ok = await _export.run(context,
        createFile: () => exportCategoryList(snapshot,
            outputDirectory: widget.exportDirectory));
    if (!ok && mounted) AppToast.error(context, 'category.export_failed'.tr);
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsExport) _export.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: Listenable.merge([_controller, _export]),
      builder: (context, _) {
        final shown = _showFilters ??
            MediaQuery.sizeOf(context).width >=
                ListLayoutBreakpoints.mobileBelow;
        final enabled = !_controller.loading && !_openingEdit;
        return ListPageScaffold<CategoryListEntry>(
            header: PageHeader(
                icon: Icons.category_rounded,
                title: 'category.title'.tr,
                subtitle: 'category.list_subtitle'.tr,
                addLabel: 'category.add'.tr,
                addShortLabel: 'category.add_short'.tr,
                onAdd: enabled ? _add : null,
                actions: [
                  HeaderAction(
                      icon: Icons.filter_alt_rounded,
                      label: 'category.filters'.tr,
                      active: shown,
                      badge: _controller.applied.isNotEmpty,
                      onPressed: () => setState(() => _showFilters = !shown)),
                  HeaderAction(
                      icon: Icons.ios_share_rounded,
                      label: _export.stage ?? 'category.export'.tr,
                      busy: _export.busy,
                      onPressed: _controller.loading ||
                              _controller.error != null ||
                              _controller.rows.isEmpty
                          ? null
                          : _exportRows),
                  HeaderAction(
                      icon: Icons.refresh_rounded,
                      label: 'category.refresh'.tr,
                      onPressed: _controller.loading ? null : _reset),
                ]),
            filters: categoryListFilters(
                search: _controller.search,
                onSearch: _controller.scheduleSearch,
                onSubmit: _controller.flushSearch,
                onReset: _reset),
            showFilters: shown,
            mobileFilterTexts: CollapsedFilterTexts(
                title: 'category.filters_title'.tr,
                collapsedSubtitle: 'category.filters_hint'.tr,
                expandedSubtitle: 'category.filters_hint'.tr),
            toolbar: _controller.error == null || _controller.rows.isEmpty
                ? null
                : AppSurface(
                    child: Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                        Text('category.load_failed'.tr,
                            style: AppTextStyles.body),
                        AppOutlinedButton(
                            label: 'category.retry'.tr, onPressed: _load)
                      ])),
            isLoading: _controller.loading,
            items: _controller.pageRows,
            columns: categoryListColumns(onEdit: _edit, enabled: enabled),
            cardBuilder: (entry, _) => CategoryListCard(
                entry: entry, onEdit: enabled ? () => _edit(entry) : null),
            emptyState: AppEmptyState(
                icon: Icons.category_outlined,
                title: _controller.error == null
                    ? 'category.no_categories'.tr
                    : 'category.load_failed'.tr,
                action: _controller.error == null
                    ? null
                    : AppOutlinedButton(
                        label: 'category.retry'.tr, onPressed: _load)),
            onRefresh: _reset,
            pagination: ListPagination(
                currentPage: _controller.page,
                totalPages: _controller.totalPages,
                itemsPerPage: CategoryListController.pageSize,
                onPageChanged: _controller.goToPage,
                countLabel: 'category.page_count'
                    .trParams({'count': '${_controller.pageRows.length}'})));
      });
}
