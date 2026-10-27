import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/ai_models.dart';
import 'ai_visual_view.dart';

/// One chat turn: the user's bubble, or the assistant's steps, charts and answer.
class AiMessageView extends StatelessWidget {
  const AiMessageView({super.key, required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.role == AiRole.user) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(
              bottom: AppSpacing.md, left: AppSpacing.xxl),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadiusDirectional.only(
              topStart: Radius.circular(14),
              topEnd: Radius.circular(14),
              bottomStart: Radius.circular(14),
              bottomEnd: Radius.circular(4),
            ),
          ),
          child: SelectableText(message.text,
              style: AppTextStyles.body.copyWith(color: AppColors.onPrimary)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.steps.isNotEmpty || message.pending)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var i = 0; i < message.steps.length; i++)
                    _StepChip(
                        label: message.steps[i],
                        active:
                            message.pending && i == message.steps.length - 1),
                  if (message.pending && message.steps.isEmpty)
                    _StepChip(label: 'ai_assistant.thinking'.tr, active: true),
                ],
              ),
            ),
          for (final visual in message.visuals) AiVisualView(visual: visual),
          if (message.text.isNotEmpty) AiMarkdown(text: message.text),
          if (message.error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                  color: AppColors.softRed,
                  borderRadius: BorderRadius.circular(AppRadius.control)),
              child: Text(message.error!,
                  style: AppTextStyles.body.copyWith(color: AppColors.red)),
            ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
          color: AppColors.softBlue,
          borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (active)
            const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: AppColors.primary))
          else
            const Icon(Icons.check_rounded, size: 12, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.caption.copyWith(color: AppColors.primary)),
        ],
      ),
    );
  }
}

/// The small markdown subset the assistant writes: headings, paragraphs,
/// bullet and numbered lists, **bold**, *italic*, `code` and [links](https://…).
class AiMarkdown extends StatelessWidget {
  const AiMarkdown({super.key, required this.text});

  final String text;

  static final _listItem = RegExp(r'^\s*([-*•]|\d+[.)])\s+');
  static final _heading = RegExp(r'^(#{1,4})\s+(.*)$');

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    final lines = text.replaceAll('\r', '').split('\n');
    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      final heading = _heading.firstMatch(line);
      if (line.trim().isEmpty) {
        i++;
      } else if (heading != null) {
        blocks.add(Padding(
          padding:
              const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xxs),
          child: _rich(context, heading.group(2)!, AppTextStyles.sectionTitle),
        ));
        i++;
      } else if (_listItem.hasMatch(line)) {
        var number = 0;
        while (i < lines.length && _listItem.hasMatch(lines[i])) {
          final marker = _listItem.firstMatch(lines[i])!.group(1)!;
          final ordered = RegExp(r'^\d').hasMatch(marker);
          number++;
          blocks.add(Padding(
            padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xs, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 18,
                    child: Text(ordered ? '$number.' : '•',
                        style: AppTextStyles.body)),
                Expanded(
                    child: _rich(context, lines[i].replaceFirst(_listItem, ''),
                        AppTextStyles.body)),
              ],
            ),
          ));
          i++;
        }
      } else if (line.trimLeft().startsWith('|')) {
        // Tables are already shown as cards; keep markdown tables readable as text.
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          if (!RegExp(r'^\s*\|?\s*:?-{2,}').hasMatch(lines[i])) {
            blocks.add(_rich(context, lines[i].replaceAll('|', '  ').trim(),
                AppTextStyles.body));
          }
          i++;
        }
      } else {
        final para = <String>[];
        while (i < lines.length &&
            lines[i].trim().isNotEmpty &&
            !_listItem.hasMatch(lines[i]) &&
            !_heading.hasMatch(lines[i])) {
          para.add(lines[i].trim());
          i++;
        }
        blocks.add(Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _rich(context, para.join('\n'), AppTextStyles.body),
        ));
      }
    }
    return SelectionArea(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: blocks));
  }

  static final _inline = RegExp(
      r'\*\*(.+?)\*\*|\*(\S(?:.*?\S)?)\*|`([^`]+)`|\[([^\]]+)\]\((https?://[^\s)]+)\)');

  Widget _rich(BuildContext context, String source, TextStyle base) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inline.allMatches(source)) {
      if (m.start > last)
        spans.add(TextSpan(text: source.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(3),
            style: const TextStyle(
                fontFamily: 'monospace', backgroundColor: AppColors.canvas)));
      } else {
        final url = Uri.parse(m.group(5)!);
        spans.add(TextSpan(
          text: m.group(4),
          style: const TextStyle(
              color: AppColors.primary, decoration: TextDecoration.underline),
          recognizer: TapGestureRecognizer()
            ..onTap =
                () => launchUrl(url, mode: LaunchMode.externalApplication),
        ));
      }
      last = m.end;
    }
    if (last < source.length) spans.add(TextSpan(text: source.substring(last)));
    return Text.rich(
        TextSpan(style: base.copyWith(height: 1.45), children: spans));
  }
}
