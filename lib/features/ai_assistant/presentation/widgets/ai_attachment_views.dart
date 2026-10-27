import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../domain/ai_models.dart';

/// Shows [image] full screen with pinch/scroll zoom. The assistant floats
/// above the app's Navigator, so this goes into the assistant's own Overlay
/// rather than a route; tap outside, the close button or Escape dismisses it.
void showAiImageViewer(BuildContext context,
    {required ImageProvider image, String? caption}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ImageViewer(
        image: image,
        caption: caption,
        onClose: () {
          if (entry.mounted) entry.remove();
        }),
  );
  overlay.insert(entry);
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer(
      {required this.image, required this.caption, required this.onClose});

  final ImageProvider image;
  final String? caption;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        key: const ValueKey('ai-image-viewer'),
        color: Colors.black.withValues(alpha: 0.85),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                    onTap: onClose, behavior: HitTestBehavior.opaque),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Image(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (caption != null && caption!.isNotEmpty)
                Positioned(
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                  bottom: AppSpacing.md,
                  child: Text(caption!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(color: Colors.white)),
                ),
              PositionedDirectional(
                top: AppSpacing.sm,
                end: AppSpacing.sm,
                child: IconButton(
                  key: const ValueKey('ai-image-viewer-close'),
                  tooltip: 'ai_assistant.close'.tr,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The files waiting in the composer: thumbnails and PDF tiles with upload
/// progress, retry and remove.
class AiAttachmentStrip extends StatelessWidget {
  const AiAttachmentStrip({
    super.key,
    required this.attachments,
    required this.onRemove,
    required this.onRetry,
  });

  final List<AiDraftAttachment> attachments;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        key: const ValueKey('ai-attachment-strip'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 6, right: 6),
        itemCount: attachments.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => _DraftTile(
          key: ValueKey('ai-attachment-tile-$i'),
          index: i,
          draft: attachments[i],
          onRemove: () => onRemove(attachments[i].key),
          onRetry: () => onRetry(attachments[i].key),
        ),
      ),
    );
  }
}

class _DraftTile extends StatelessWidget {
  const _DraftTile({
    super.key,
    required this.index,
    required this.draft,
    required this.onRemove,
    required this.onRetry,
  });

  final int index;
  final AiDraftAttachment draft;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = draft.status == AiUploadStatus.failed;
    final uploading = draft.status == AiUploadStatus.uploading;
    final image = draft.kind == AiAttachmentKind.image;
    final meta = uploading
        ? 'ai_assistant.attach_reading'.tr
        : failed
            ? 'ai_assistant.attach_failed'.tr
            : _pdfMeta(draft.uploaded?.pages);
    return Tooltip(
      message: draft.error ?? draft.name,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: image ? 60 : 172,
            height: 60,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(
                  color: failed ? AppColors.red : AppColors.border,
                  width: failed ? 1.5 : 1),
            ),
            child: image
                ? (draft.preview == null
                    ? const Icon(Icons.image_outlined, color: AppColors.muted)
                    : Image.memory(draft.preview!,
                        fit: BoxFit.cover, gaplessPlayback: true))
                : _PdfLabel(name: draft.name, meta: meta),
          ),
          if (uploading || failed)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                alignment: Alignment.center,
                child: uploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary))
                    : IconButton(
                        key: ValueKey('ai-attachment-retry-$index'),
                        tooltip: 'ai_assistant.attach_retry'.tr,
                        visualDensity: VisualDensity.compact,
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded,
                            size: 20, color: AppColors.red),
                      ),
              ),
            ),
          PositionedDirectional(
            top: -6,
            end: -6,
            child: Semantics(
              button: true,
              label: 'ai_assistant.attach_remove'.tr,
              child: InkWell(
                key: ValueKey('ai-attachment-remove-$index'),
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border)),
                  child: const Icon(Icons.close_rounded,
                      size: 13, color: AppColors.muted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _pdfMeta(int? pages) => pages == null
    ? 'ai_assistant.attach_pdf'.tr
    : 'ai_assistant.attach_pdf_pages'.trParams({'count': '$pages'});

class _PdfLabel extends StatelessWidget {
  const _PdfLabel({required this.name, required this.meta});

  final String name;
  final String meta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded,
              size: 26, color: AppColors.red),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The images and PDFs sent with a question, above its bubble. Images open
/// full screen; reloaded chats load their thumbnails through [load].
class AiMessageAttachments extends StatelessWidget {
  const AiMessageAttachments({super.key, required this.attachments, this.load});

  final List<AiAttachment> attachments;
  final Future<Uint8List> Function(String id)? load;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (var i = 0; i < attachments.length; i++)
          attachments[i].kind == AiAttachmentKind.image
              ? _ImageThumb(
                  key: ValueKey('ai-message-attachment-$i'),
                  attachment: attachments[i],
                  load: load)
              : Container(
                  key: ValueKey('ai-message-attachment-$i'),
                  constraints: const BoxConstraints(maxWidth: 220),
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: _PdfLabel(
                      name: attachments[i].name,
                      meta: _pdfMeta(attachments[i].pages)),
                ),
      ],
    );
  }
}

class _ImageThumb extends StatefulWidget {
  const _ImageThumb({super.key, required this.attachment, this.load});

  final AiAttachment attachment;
  final Future<Uint8List> Function(String id)? load;

  @override
  State<_ImageThumb> createState() => _ImageThumbState();
}

class _ImageThumbState extends State<_ImageThumb> {
  Future<Uint8List>? _remote;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.preview == null && widget.load != null) {
      _remote = widget.load!(widget.attachment.id);
    }
  }

  Widget _frame(Widget child, {Uint8List? bytes}) => Tooltip(
        message: widget.attachment.name,
        child: GestureDetector(
          onTap: bytes == null
              ? null
              : () => showAiImageViewer(context,
                  image: MemoryImage(bytes), caption: widget.attachment.name),
          child: Container(
            width: 96,
            height: 96,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: child,
          ),
        ),
      );

  Widget _image(Uint8List bytes) =>
      _frame(Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
          bytes: bytes);

  @override
  Widget build(BuildContext context) {
    final preview = widget.attachment.preview;
    if (preview != null) return _image(preview);
    if (_remote == null) return _frame(_unavailable());
    return FutureBuilder<Uint8List>(
      future: _remote,
      builder: (context, snap) {
        if (snap.hasData && snap.data!.isNotEmpty) return _image(snap.data!);
        if (snap.hasError) return _frame(_unavailable());
        return _frame(const Center(
            child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary))));
      },
    );
  }

  Widget _unavailable() => Tooltip(
        message: 'ai_assistant.attach_unavailable'.tr,
        child: const Icon(Icons.broken_image_outlined, color: AppColors.muted),
      );
}
