import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'build_dialog_box.dart';
import '../resources/color_manager.dart';

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

  @override
  State<ExportShareButton> createState() => _ExportShareButtonState();
}

class _ExportShareButtonState extends State<ExportShareButton> {
  bool _isExporting = false;

  void _startExport() {
    unawaited(_exportAndShare());
  }

  Future<void> _exportAndShare() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final file = await widget.createFile();
      if (!file.existsSync()) {
        throw StateError('The exported file was not created.');
      }
      if (!mounted) return;

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
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareFile(File file, Rect? shareOrigin) async {
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
    final icon = _isExporting
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.compact ? ColorManager.kPrimaryColor : Colors.white,
            ),
          )
        : const Icon(Icons.ios_share, size: 20);

    if (widget.compact) {
      return IconButton(
        onPressed: _isExporting || !widget.enabled ? null : _startExport,
        icon: IconTheme(
          data: const IconThemeData(color: ColorManager.kPrimaryColor),
          child: icon,
        ),
        tooltip: _isExporting ? widget.loadingLabel : widget.tooltip,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      );
    }

    return ElevatedButton(
      onPressed: _isExporting || !widget.enabled ? null : _startExport,
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorManager.kPrimaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ColorManager.kPrimaryColor.withValues(
          alpha: 0.45,
        ),
        disabledForegroundColor: Colors.white70,
        fixedSize: const Size(150, 45),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Text(_isExporting ? widget.loadingLabel : widget.label),
    );
  }
}
