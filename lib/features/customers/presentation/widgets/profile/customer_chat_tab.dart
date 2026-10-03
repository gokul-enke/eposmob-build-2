import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../domain/models/customer_list.dart';
import '../../state/customer_chat_controller.dart';
import '../customer_labels.dart';
import 'chat/customer_chat_widgets.dart';

/// Conversation with the customer.
class CustomerChatTab extends StatefulWidget {
  const CustomerChatTab({super.key, required this.customer, this.controller});

  final CustomerListModelData customer;

  /// Injected for tests; by default the tab creates (and disposes) its own.
  final CustomerChatController? controller;

  @override
  State<CustomerChatTab> createState() => _CustomerChatTabState();
}

class _CustomerChatTabState extends State<CustomerChatTab> {
  late final CustomerChatController _chat = widget.controller ??
      CustomerChatController(customerId: widget.customer.id);
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _chat.addListener(_onChanged);
    _chat.load();
  }

  @override
  void dispose() {
    _chat.removeListener(_onChanged);
    if (widget.controller == null) _chat.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _send() {
    if (!_chat.send(_input.text)) return;
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = CustomerLabels.name(widget.customer.name);
    return AppSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          CustomerChatHeader(name: name, rawName: widget.customer.name),
          Expanded(child: _body(name)),
          if (!_chat.isLoading && !_chat.hasError)
            CustomerChatInput(controller: _input, onSend: _send),
        ],
      ),
    );
  }

  Widget _body(String name) {
    if (_chat.isLoading) return const AppLoadingView(useSurface: false);
    if (_chat.hasError) {
      return _scrollable(
        AppEmptyState(
          icon: Icons.error_outline,
          title: 'customer_chat.title_error'.tr,
          subtitle: 'customer_chat.err_load'.tr,
          action: AppOutlinedButton(
            label: 'customer_chat.btn_try_again'.tr,
            icon: Icons.refresh,
            onPressed: _chat.load,
          ),
        ),
      );
    }
    final messages = _chat.messages;
    if (messages.isEmpty) {
      return _scrollable(
        AppEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'customer_chat.title_no_messages'.tr,
          subtitle: '${'customer_chat.msg_start_conversation'.tr} $name.',
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: messages.length,
        itemBuilder: (_, index) => CustomerChatBubble(
          message: messages[index],
          maxWidth: constraints.maxWidth * 0.75,
        ),
      ),
    );
  }

  /// Centers [child] but lets it scroll when the keyboard leaves too little
  /// room.
  Widget _scrollable(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }
}
