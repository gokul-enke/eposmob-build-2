import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/helpers/date_helper.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';

/// Shows every server attempt for one local sale: the exact request body, the
/// raw response and the outcome. Updates live while a retry is in flight.
class LocalSaleSyncLogDialog extends StatelessWidget {
  const LocalSaleSyncLogDialog({super.key, required this.localOrderId});

  final String localOrderId;

  static String _time(String iso) => _AttemptTile._time(iso);

  @override
  Widget build(BuildContext context) {
    final record = context.watch<LocalSaleSyncService>().recordFor(
          localOrderId,
        );
    final attempts = record?.attempts.reversed.toList() ?? const [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sync log · ${record?.localOrderNumber ?? localOrderId}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F3D75),
                      ),
                    ),
                  ),
                  if (record != null)
                    TextButton.icon(
                      onPressed: () => _copy(
                        context,
                        const JsonEncoder.withIndent('  ')
                            .convert(record.toJson()),
                        'Full log copied.',
                      ),
                      icon: const Icon(Icons.copy_all_outlined, size: 17),
                      label: const Text('Copy all'),
                    ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (record?.message?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Current status: ${record!.state.value} — ${record.message}',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                  ),
                ),
              ],
              if (record?.isDismissed == true) ...[
                const SizedBox(height: 4),
                Text(
                  'Removed ${LocalSaleSyncLogDialog._time(record!.dismissedAt!)}'
                  ' — ${record.dismissNote ?? ''}',
                  style: const TextStyle(
                    color: Color(0xFFB42318),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: attempts.isEmpty
                    ? const Center(
                        child: Text(
                          'No request has been sent for this sale yet.',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(right: 8),
                        itemCount: attempts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _AttemptTile(
                          attempt: attempts[index],
                          initiallyExpanded: index == 0,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({required this.attempt, required this.initiallyExpanded});

  final LocalSaleSyncAttempt attempt;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (attempt.outcome) {
      'synced' => ('Synced', const Color(0xFF16764A)),
      'rejected' => ('Rejected', const Color(0xFFB42318)),
      'needs_review' => ('Needs review', const Color(0xFFB45309)),
      null => ('Waiting for response', const Color(0xFF2563EB)),
      final other => (other, const Color(0xFF6B7280)),
    };
    final status = attempt.httpStatus != null
        ? 'HTTP ${attempt.httpStatus}'
        : (attempt.isFinished ? 'No response' : 'Sending…');

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        title: Text(
          'Attempt ${attempt.number} · $status · $label',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${_time(attempt.startedAt)}'
          '${attempt.finishedAt != null ? ' → ${_time(attempt.finishedAt!)}' : ''}'
          '\n${attempt.endpoint}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (attempt.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Error: ${attempt.error}',
                style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _BodyBlock(title: 'Request body', body: attempt.requestBody),
          const SizedBox(height: 10),
          _BodyBlock(
            title: 'Response body',
            body: attempt.responseBody ??
                (attempt.isFinished ? '(no response)' : '(waiting…)'),
          ),
        ],
      ),
    );
  }

  static String _time(String iso) {
    if (iso.isEmpty) return '-';
    return '${DateHelper.formatToISODateOnlyFromISO(iso)} '
        '${DateHelper.formatToISODateFromIST(iso)}';
  }
}

class _BodyBlock extends StatelessWidget {
  const _BodyBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final pretty = _pretty(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _copy(context, pretty, '$title copied.'),
              icon: const Icon(Icons.copy, size: 15),
              label: const Text('Copy'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              pretty,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  static String _pretty(String body) {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(body));
    } catch (_) {
      return body;
    }
  }
}

void _copy(BuildContext context, String text, String message) {
  Clipboard.setData(ClipboardData(text: text));
  AppToast.success(context, message, duration: const Duration(seconds: 2));
}
