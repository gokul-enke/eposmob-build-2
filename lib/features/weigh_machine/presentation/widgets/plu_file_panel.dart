import 'package:flutter/material.dart';
import 'package:pos_machine/features/weigh_machine/domain/plu_csv.dart';
import 'package:pos_machine/resources/color_manager.dart';

import 'weigh_ui.dart';

/// Which export button is currently running, so only that one shows progress.
enum PluTask { download, sync, excel }

class PluLastSave {
  const PluLastSave({
    required this.at,
    required this.count,
    required this.path,
  });

  final DateTime at;
  final int count;
  final String path;
}

/// The machine-file card: readiness, save folder, auto-update and the export
/// actions. Everything needed to produce PLU.csv lives here, so users never
/// open a separate settings dialog for the common path.
class PluFilePanel extends StatelessWidget {
  const PluFilePanel({
    super.key,
    required this.selectedCount,
    required this.weightedCount,
    required this.destination,
    required this.autoEnabled,
    required this.running,
    required this.lastSave,
    required this.onDownload,
    required this.onSyncDownload,
    required this.onChooseFolder,
    this.onUseDefaultFolder,
    required this.onAutoChanged,
    this.showDownload = true,
    this.folderHint,
  });

  final int selectedCount;
  final int weightedCount;
  final String? destination;
  final bool autoEnabled;
  final PluTask? running;
  final PluLastSave? lastSave;
  final VoidCallback onDownload;
  final VoidCallback onSyncDownload;
  final VoidCallback onChooseFolder;

  /// Shown only when a custom folder is set; returns to Documents/epos/PLU.
  final VoidCallback? onUseDefaultFolder;
  final ValueChanged<bool> onAutoChanged;

  /// Narrow layouts show Download in the sticky selection bar instead.
  final bool showDownload;
  final String? folderHint;

  bool get _ready => selectedCount > 0;

  @override
  Widget build(BuildContext context) {
    final busy = running != null;
    return WeighSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              WeighIconTile(icon: Icons.description_outlined),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PluCsv.fileName,
                      style: TextStyle(
                        color: WeighUiColors.heading,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'The file your weigh machine imports.',
                      style:
                          TextStyle(color: WeighUiColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _StatusBanner(
            ready: _ready,
            selectedCount: selectedCount,
            weightedCount: weightedCount,
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Save folder'),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            decoration: BoxDecoration(
              color: WeighUiColors.canvas,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined,
                    size: 18, color: WeighUiColors.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Tooltip(
                    message: destination ?? '',
                    child: Text(
                      destination ?? 'Loading…',
                      key: const ValueKey('plu_destination'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: WeighUiColors.body,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('plu_choose_folder'),
                  onPressed: busy ? null : onChooseFolder,
                  style: TextButton.styleFrom(
                    foregroundColor: ColorManager.kPrimaryColor,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
          if (onUseDefaultFolder != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('plu_default_folder'),
                onPressed: busy ? null : onUseDefaultFolder,
                icon: const Icon(Icons.undo_rounded, size: 16),
                label: const Text('Use default folder'),
                style: TextButton.styleFrom(
                  foregroundColor: ColorManager.kPrimaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (folderHint != null) ...[
            const SizedBox(height: 6),
            Text(
              folderHint!,
              style: const TextStyle(color: WeighUiColors.muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            key: const ValueKey('plu_auto_switch'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: ColorManager.kPrimaryColor,
            activeTrackColor: ColorManager.kPrimaryColor.withValues(alpha: 0.3),
            title: const Text(
              'Keep file up to date',
              style: TextStyle(
                color: WeighUiColors.heading,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: const Text(
              'Rewrites PLU.csv when prices or selected items change.',
              style: TextStyle(color: WeighUiColors.muted, fontSize: 12),
            ),
            value: autoEnabled,
            onChanged: onAutoChanged,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: WeighUiColors.subtleBorder),
          const SizedBox(height: 16),
          if (showDownload) ...[
            PluDownloadButton(
              enabled: _ready && !busy,
              running: running == PluTask.download,
              onPressed: onDownload,
            ),
            const SizedBox(height: 8),
          ],
          Tooltip(
            message: 'Fetch the latest catalog and prices, then save PLU.csv.',
            child: OutlinedButton.icon(
              key: const ValueKey('plu_sync'),
              onPressed: busy ? null : onSyncDownload,
              icon: running == PluTask.sync
                  ? const _ButtonSpinner(color: ColorManager.kPrimaryColor)
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                  running == PluTask.sync ? 'Syncing…' : 'Sync & download'),
              style: weighSecondaryButtonStyle(),
            ),
          ),
          if (lastSave != null) ...[
            const SizedBox(height: 14),
            _LastSaved(lastSave!),
          ],
        ],
      ),
    );
  }
}

class PluDownloadButton extends StatelessWidget {
  const PluDownloadButton({
    super.key,
    required this.enabled,
    required this.running,
    required this.onPressed,
    this.label = 'Download PLU.csv',
  });

  final bool enabled;
  final bool running;
  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey('plu_download'),
      onPressed: enabled ? onPressed : null,
      icon: running
          ? const _ButtonSpinner(color: Colors.white)
          : const Icon(Icons.download_rounded, size: 18),
      label: Text(running ? 'Saving…' : label),
      style: weighPrimaryButtonStyle(),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.ready,
    required this.selectedCount,
    required this.weightedCount,
  });

  final bool ready;
  final int selectedCount;
  final int weightedCount;

  @override
  Widget build(BuildContext context) {
    final background =
        ready ? WeighUiColors.softGreen : WeighUiColors.softAmber;
    final foreground = ready ? WeighUiColors.green : WeighUiColors.amber;
    final title = ready
        ? '${WeighFormat.products(selectedCount)} ready'
        : 'No products selected';
    final message = ready
        ? 'These items will be written to the machine file.'
        : weightedCount > 0
            ? 'Tick products in the list, or use the Weighted filter to find '
                'the ${WeighFormat.count(weightedCount)} flagged items.'
            : 'Tick the products your weigh machine sells by weight.';

    return Container(
      key: const ValueKey('plu_status'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 20,
            color: foreground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: WeighUiColors.body,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LastSaved extends StatelessWidget {
  const _LastSaved(this.save);

  final PluLastSave save;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(save.at).format(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.history_rounded, size: 16, color: WeighUiColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: save.path,
            child: Text(
              'Last saved at $time · ${WeighFormat.products(save.count)}',
              style: const TextStyle(color: WeighUiColors.muted, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: WeighUiColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}
