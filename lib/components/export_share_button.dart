import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import 'build_dialog_box.dart';
import '../resources/color_manager.dart';
import '../core/ui/app_colors.dart';

typedef ShareExportFile = Future<void> Function(File file, Rect? shareOrigin);

/// Reusable action that creates a file and opens the platform share menu.
class ExportShareButton extends StatefulWidget {
  const ExportShareButton({
    super.key,
    required this.createFile,
    required this.label,
    required this.loadingLabel,
    required this.tooltip,
    required this.errorMessage,
    required this.mimeType,
    this.shareText,
    this.compact = false,
    this.enabled = true,
    this.shareFile,
    this.progressLabel,
  });

  final Future<File> Function() createFile;
  final String label;
  final String loadingLabel;
  final String tooltip;
  final String errorMessage;
  final String mimeType;
  final String? shareText;
  final bool compact;
  final bool enabled;
  final ShareExportFile? shareFile;
  final ValueListenable<String?>? progressLabel;

  @override
  State<ExportShareButton> createState() => _ExportShareButtonState();
}

class _ExportShareButtonState extends State<ExportShareButton> {
  bool _isExporting = false;
  String? _stage;

  void _startExport() {
    unawaited(_exportAndShare());
  }

  Future<void> _exportAndShare() async {
    if (_isExporting) return;
    setState(() {
      _isExporting = true;
      _stage = null;
    });

    try {
      final file = await widget.createFile();
      if (!file.existsSync()) {
        throw StateError('The exported file was not created.');
      }
      if (!mounted) return;

      debugPrint('Export: file generated; opening save/share dialog');

      final renderBox = context.findRenderObject();
      final origin = renderBox is RenderBox && renderBox.hasSize
          ? renderBox.localToGlobal(Offset.zero) & renderBox.size
          : null;
      final shareFile = widget.shareFile ?? _shareFile;
      await shareFile(file, origin);
    } catch (error) {
      if (!mounted) return;
      debugPrint('Export/share failed: $error');
      showScaffoldError(
        context: context,
        message: widget.errorMessage,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _stage = null;
        });
      }
    }
  }

  Future<void> _shareFile(File file, Rect? shareOrigin) async {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Save exports directly on Windows instead of invoking the native
      // DataTransferManager share UI, which can terminate the app process.
      setState(() => _stage = 'list.export_waiting_save'.tr);
      final destination = await FilePicker.platform.saveFile(
        fileName: file.uri.pathSegments.last,
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        lockParentWindow: true,
      );
      debugPrint(destination == null
          ? 'Export: Save As cancelled'
          : 'Export: Save As destination selected');
      if (destination == null) return;
      final path = destination.toLowerCase().endsWith('.xlsx')
          ? destination
          : '$destination.xlsx';
      // The native dialog only confirmed its returned path, not an appended extension.
      if (path != destination && await File(path).exists()) {
        if (!mounted) return;
        final overwrite = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: Text('list.export_overwrite_title'.tr),
                  content: Text('list.export_overwrite_message'
                      .trParams({'name': File(path).uri.pathSegments.last})),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('list.export_cancel'.tr)),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('list.export_overwrite'.tr)),
                  ],
                ));
        if (overwrite != true) return;
      }
      if (File(path).absolute.path.toLowerCase() !=
          file.absolute.path.toLowerCase()) {
        if (mounted) setState(() => _stage = 'list.export_saving'.tr);
        await file.copy(path);
      }
      return;
    }
    setState(() => _stage = 'list.export_waiting_share'.tr);
    final params = ShareParams(
      files: [
        XFile(
          file.path,
          name: file.uri.pathSegments.last,
          mimeType: widget.mimeType,
          length: await file.length(),
        ),
      ],
      text: widget.shareText,
      sharePositionOrigin: shareOrigin,
    );
    await SharePlus.instance.share(params);
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progressLabel;
    if (progress == null) return _buildButton(context, null);
    return ValueListenableBuilder<String?>(
        valueListenable: progress,
        builder: (context, value, _) => _buildButton(context, value));
  }

  Widget _buildButton(BuildContext context, String? progress) {
    final loadingLabel = _stage ?? progress ?? widget.loadingLabel;
    final icon = _isExporting
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : const Icon(Icons.ios_share, size: 20);

    if (widget.compact) {
      return IconButton.filled(
        onPressed: _isExporting || !widget.enabled ? null : _startExport,
        icon: IconTheme(
          data: const IconThemeData(color: Colors.white),
          child: icon,
        ),
        tooltip: _isExporting ? loadingLabel : widget.tooltip,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        style: IconButton.styleFrom(
          fixedSize: const Size(44, 44),
          backgroundColor: ColorManager.kPrimaryColor,
          disabledBackgroundColor:
              ColorManager.kPrimaryColor.withValues(alpha: .45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      );
    }

    // Reserve space using the idle label, so progress cannot reflow the header.
    final labelStyle = FilledButtonTheme.of(context)
            .style
            ?.textStyle
            ?.resolve(const <WidgetState>{}) ??
        Theme.of(context).textTheme.labelLarge;
    final labelPainter = TextPainter(
      text: TextSpan(text: widget.label, style: labelStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final labelWidth = labelPainter.width + 32;
    labelPainter.dispose();
    final buttonWidth = labelWidth < 150 ? 150.0 : labelWidth;
    return Tooltip(
      message: _isExporting ? loadingLabel : widget.tooltip,
      child: SizedBox(
        width: buttonWidth,
        child: FilledButton(
          onPressed: _isExporting || !widget.enabled ? null : _startExport,
          style: FilledButton.styleFrom(
            backgroundColor: ColorManager.kPrimaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: ColorManager.kPrimaryColor.withValues(
              alpha: 0.45,
            ),
            disabledForegroundColor: Colors.white70,
            minimumSize: const Size(150, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
          ),
          child: Text(_isExporting ? loadingLabel : widget.label,
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}
