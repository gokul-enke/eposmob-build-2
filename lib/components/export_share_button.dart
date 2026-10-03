import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'build_dialog_box.dart';
import '../resources/color_manager.dart';
import '../core/export/file_export_service.dart';
import '../core/ui/tokens/app_spacing.dart';

typedef ShareExportFile = Future<void> Function(File file, Rect? shareOrigin);

/// Button that creates a file and hands it to the user (Save As on Windows,
/// the share sheet elsewhere). Pages using [PageHeader] can use
/// [ExportController] with a [HeaderAction] instead.
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

  /// Save As on Windows, share sheet elsewhere (see [FileExportService]).
  Future<void> _shareFile(File file, Rect? shareOrigin) {
    return FileExportService.deliver(
      context,
      file,
      mimeType: widget.mimeType,
      shareText: widget.shareText,
      shareOrigin: shareOrigin,
      onStage: (stage) {
        if (mounted) setState(() => _stage = stage);
      },
    );
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
