import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../components/build_container_box.dart';
import '../../../resources/color_manager.dart';
import 'dashboard_responsive.dart';

/// One independent request with bounded API loading, retry and stale-result
/// protection. Parent rebuilds (e.g. currency/locale) do not refetch its data.
class DashboardDataSection<T> extends StatefulWidget {
  const DashboardDataSection({
    super.key,
    required this.title,
    required this.requestKey,
    required this.load,
    required this.builder,
  });
  final String title;
  final Object requestKey;
  final Future<T> Function() load;
  final Widget Function(T) builder;

  @override
  State<DashboardDataSection<T>> createState() =>
      _DashboardDataSectionState<T>();
}

class _DashboardDataSectionState<T> extends State<DashboardDataSection<T>> {
  T? _data;
  bool _loading = true;
  bool _failed = false;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DashboardDataSection<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requestKey != widget.requestKey) _load();
  }

  Future<void> _load() async {
    final version = ++_version;
    setState(() {
      _loading = true;
      _failed = false;
      _data = null;
    });
    try {
      final result = await widget.load();
      if (mounted && version == _version) setState(() => _data = result);
    } catch (_) {
      if (mounted && version == _version) setState(() => _failed = true);
    } finally {
      if (mounted && version == _version) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _version++;
    super.dispose();
  }

  Widget _message(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: BuildBoxShadowContainer(
          circleRadius: 14,
          padding: const EdgeInsets.all(16),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardSectionHeader(
              title: widget.title,
              trailing: IconButton(
                tooltip: 'dashboard.new_widgets.refresh'.tr,
                onPressed: _loading ? null : _load,
                color: ColorManager.kPrimaryColor,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ),
            if (_loading)
              _message(const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator.adaptive()),
              ))
            else if (_failed)
              _message(Row(children: [
                const Icon(Icons.cloud_off_rounded, color: ColorManager.kRed),
                const SizedBox(width: 10),
                Expanded(child: Text('dashboard.new_widgets.load_failed'.tr)),
                TextButton(
                  onPressed: _load,
                  child: Text('general.retry'.tr),
                ),
              ]))
            else if (_data != null)
              widget.builder(_data as T),
          ],
        ),
      );
}
