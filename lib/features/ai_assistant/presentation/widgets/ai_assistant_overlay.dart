import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pos_machine/config/brand_config.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../domain/ai_models.dart';
import '../state/ai_assistant_controller.dart';
import 'ai_message_view.dart';

/// The brand's mark for the floating button: the CloudPOS cloud for the
/// default brand, otherwise the white-label brand's own icon.
String get aiAssistantIconAsset => BrandConfig.isDefault
    ? 'assets/logo/cloudpos-mark.png'
    : BrandConfig.iconAsset;

/// Floats the assistant above every signed-in page (added once in the app
/// builder). Closed: a draggable round CloudPOS button. Open: a docked panel
/// on tablets/desktop, full screen on phones. The chat survives both.
class AiAssistantOverlay extends StatelessWidget {
  const AiAssistantOverlay({super.key, this.controller});

  /// Injected for tests; defaults to the app-wide instance.
  final AiAssistantController? controller;

  @override
  Widget build(BuildContext context) {
    final chat = controller ?? AiAssistantController.instance;
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        if (!chat.available) return const SizedBox.shrink();
        // This sits above the app's Navigator, so it brings its own Overlay
        // (text selection, tooltips) and Material.
        return Overlay(
          key: const ValueKey('ai-assistant-overlay'),
          initialEntries: [
            OverlayEntry(
              maintainState: true,
              builder: (context) => _Layout(chat: chat),
            ),
          ],
        );
      },
    );
  }
}

class _Layout extends StatelessWidget {
  const _Layout({required this.chat});

  final AiAssistantController chat;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: chat,
      builder: (context, _) {
        final size = MediaQuery.sizeOf(context);
        final phone = size.width < 640;
        if (chat.state == AiPanelState.closed) {
          // Home corner is bottom-right; the offset is where the user dragged it.
          const margin = 20.0;
          final maxX = size.width - _Launcher.size - margin * 2;
          final maxY = size.height - _Launcher.size - margin * 2;
          // Offsets are ≤ 0 (left/up of home) and kept on screen.
          Offset clamp(Offset o) => Offset(
                o.dx.clamp(maxX < 0 ? 0.0 : -maxX, 0.0),
                o.dy.clamp(maxY < 0 ? 0.0 : -maxY, 0.0),
              );
          final offset = clamp(chat.launcherOffset);
          return Stack(children: [
            Positioned(
              right: margin - offset.dx,
              bottom: margin - offset.dy,
              child: _Launcher(
                chat: chat,
                onDrag: (delta) =>
                    chat.setLauncherOffset(clamp(offset + delta)),
              ),
            ),
          ]);
        }
        final panel = _Panel(chat: chat, phone: phone);
        if (phone) return Positioned.fill(child: panel);
        return Stack(children: [
          PositionedDirectional(
            end: 16,
            bottom: 16,
            width: size.width < 900 ? 380 : 420,
            height: (size.height - 32).clamp(360.0, 700.0),
            child: panel,
          ),
        ]);
      },
    );
  }
}

/// Round CloudPOS button: tap to open, drag to move out of the way. A ring
/// spins while an answer streams; a green dot means an unseen answer.
class _Launcher extends StatelessWidget {
  const _Launcher({required this.chat, required this.onDrag});

  static const double size = 56;

  final AiAssistantController chat;
  final ValueChanged<Offset> onDrag;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'ai_assistant.launcher_tooltip'.tr,
      child: GestureDetector(
        key: const ValueKey('ai-assistant-launcher'),
        onTap: chat.open,
        onPanUpdate: (d) => onDrag(d.delta),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  elevation: 6,
                  shape: const CircleBorder(
                      side: BorderSide(color: AppColors.border)),
                  color: AppColors.surface,
                  child: Center(
                    child: Image.asset(aiAssistantIconAsset,
                        width: 38,
                        height: 38,
                        filterQuality: FilterQuality.medium),
                  ),
                ),
                if (chat.busy)
                  const Positioned.fill(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary),
                  ),
                if (chat.hasUnread && !chat.busy)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      key: const ValueKey('ai-assistant-unread'),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8EC63D),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.chat, required this.phone});

  final AiAssistantController chat;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('ai-assistant-panel'),
      elevation: phone ? 0 : 12,
      color: AppColors.canvas,
      borderRadius: phone ? null : BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: phone,
        bottom: phone,
        left: false,
        right: false,
        child: Column(
          children: [
            _Header(chat: chat),
            Expanded(
                child: chat.showHistory
                    ? _HistoryList(chat: chat)
                    : _MessageList(chat: chat)),
            if (!chat.showHistory) _Composer(chat: chat),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.chat});

  final AiAssistantController chat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
      decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Image.asset(aiAssistantIconAsset, width: 32, height: 32),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ai_assistant.title'.tr,
                    style: AppTextStyles.sectionTitle),
                Text('ai_assistant.subtitle'.tr,
                    style: AppTextStyles.sectionHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _HeaderButton(
            key: const ValueKey('ai-assistant-history'),
            icon: chat.showHistory
                ? Icons.chat_bubble_outline_rounded
                : Icons.history_rounded,
            tooltip: chat.showHistory
                ? 'ai_assistant.back_to_chat'.tr
                : 'ai_assistant.history'.tr,
            onPressed: chat.toggleHistory,
          ),
          _HeaderButton(
            key: const ValueKey('ai-assistant-new-chat'),
            icon: Icons.add_comment_outlined,
            tooltip: 'ai_assistant.new_chat'.tr,
            onPressed: chat.busy ? null : chat.newChat,
          ),
          _HeaderButton(
            key: const ValueKey('ai-assistant-close'),
            icon: Icons.close_rounded,
            tooltip: 'ai_assistant.close'.tr,
            onPressed: chat.close,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton(
      {super.key,
      required this.icon,
      required this.tooltip,
      required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: AppColors.muted),
      );
}

class _MessageList extends StatefulWidget {
  const _MessageList({required this.chat});

  final AiAssistantController chat;

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followNewContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.chat.messages;
    if (messages.isEmpty) return _Welcome(chat: widget.chat);
    if (messages.length != _lastCount || widget.chat.busy) {
      _lastCount = messages.length;
      _followNewContent();
    }
    return ListView.builder(
      key: const ValueKey('ai-assistant-messages'),
      controller: _scroll,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: messages.length,
      itemBuilder: (context, i) => AiMessageView(message: messages[i]),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.chat});

  final AiAssistantController chat;

  static const _suggestions = [
    'ai_assistant.suggest_this_page',
    'ai_assistant.suggest_sales_week',
    'ai_assistant.suggest_low_stock',
    'ai_assistant.suggest_top_products',
    'ai_assistant.suggest_how_printer',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('ai_assistant.welcome_title'.tr,
            style: AppTextStyles.pageTitleCompact),
        const SizedBox(height: AppSpacing.xs),
        Text('ai_assistant.welcome_body'.tr, style: AppTextStyles.pageSubtitle),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final key in _suggestions)
              ActionChip(
                label: Text(key.tr, style: AppTextStyles.body),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                onPressed: () => chat.send(key.tr),
              ),
          ],
        ),
      ],
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({required this.chat});

  final AiAssistantController chat;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty || widget.chat.busy) return;
    _input.clear();
    widget.chat.send(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final page = chat.currentPage;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
      decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: FilterChip(
                key: const ValueKey('ai-assistant-page-context'),
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.visibility_outlined, size: 14),
                label: Text(
                  'ai_assistant.using_page'.trParams({'page': page.screen}),
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: chat.usePageContext,
                showCheckmark: false,
                selectedColor: AppColors.softBlue,
                onSelected: chat.setUsePageContext,
                tooltip: 'ai_assistant.using_page_hint'.tr,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('ai-assistant-input'),
                  controller: _input,
                  focusNode: _focus,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: AppTextStyles.input,
                  decoration: InputDecoration(
                    hintText: 'ai_assistant.placeholder'.tr,
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.canvas,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.md),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                key: const ValueKey('ai-assistant-send'),
                tooltip: 'ai_assistant.send'.tr,
                onPressed: chat.busy ? null : _send,
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: chat.busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.onPrimary))
                    : const Icon(Icons.arrow_upward_rounded,
                        color: AppColors.onPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatefulWidget {
  const _HistoryList({required this.chat});

  final AiAssistantController chat;

  @override
  State<_HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<_HistoryList> {
  String? _confirmDelete;

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    if (chat.historyLoading && chat.history.isEmpty)
      return const AppLoadingView(useSurface: false);
    return ListView(
      key: const ValueKey('ai-assistant-history-list'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      children: [
        if (chat.historyError != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(chat.historyError!,
                style: AppTextStyles.body.copyWith(color: AppColors.red)),
          ),
        if (chat.history.isEmpty && chat.historyError == null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('ai_assistant.no_history'.tr,
                style: AppTextStyles.pageSubtitle),
          ),
        for (final c in chat.history) _historyTile(chat, c),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text('ai_assistant.history_note'.tr,
              style: AppTextStyles.caption),
        ),
      ],
    );
  }

  Widget _historyTile(AiAssistantController chat, AiConversationSummary c) {
    final active = c.id == chat.conversationId;
    if (_confirmDelete == c.id) {
      return ListTile(
        dense: true,
        title:
            Text('ai_assistant.delete_confirm'.tr, style: AppTextStyles.body),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
                onPressed: () => setState(() => _confirmDelete = null),
                child: Text('ai_assistant.cancel'.tr)),
            TextButton(
              onPressed: () {
                setState(() => _confirmDelete = null);
                chat.deleteConversation(c.id);
              },
              child: Text('ai_assistant.delete'.tr,
                  style: const TextStyle(color: AppColors.red)),
            ),
          ],
        ),
      );
    }
    return ListTile(
      dense: true,
      selected: active,
      selectedTileColor: AppColors.softBlue,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control)),
      title: Text(c.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.body),
      subtitle: Text(DateFormat.yMMMd().add_jm().format(c.updatedAt),
          style: AppTextStyles.caption),
      onTap: () => chat.openConversation(c.id),
      trailing: IconButton(
        tooltip: 'ai_assistant.delete'.tr,
        icon: const Icon(Icons.delete_outline_rounded,
            size: 18, color: AppColors.muted),
        onPressed: () => setState(() => _confirmDelete = c.id),
      ),
    );
  }
}
