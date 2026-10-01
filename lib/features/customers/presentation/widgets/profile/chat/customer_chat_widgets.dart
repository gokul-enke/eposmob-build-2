import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';

import '../../../state/customer_chat_controller.dart';
import '../../customer_avatar.dart';

/// Avatar, name and status line above the conversation.
class CustomerChatHeader extends StatelessWidget {
  const CustomerChatHeader(
      {super.key, required this.name, required this.rawName});

  /// Display name (already translated when the customer is unnamed).
  final String name;

  /// The raw customer name, for the avatar initial.
  final String? rawName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      child: Row(
        children: [
          CustomerAvatar(name: rawName, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  'customer_chat.label_online'.tr,
                  style: AppTextStyles.caption.copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One message bubble; the store's messages sit on the end side.
class CustomerChatBubble extends StatelessWidget {
  const CustomerChatBubble({
    super.key,
    required this.message,
    required this.maxWidth,
  });

  final CustomerChatMessage message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe;
    const corner = Radius.circular(16);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(message.sentAt));

    return Align(
      alignment: isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.lg,
        ),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.softBlue,
          borderRadius: BorderRadiusDirectional.only(
            topStart: corner,
            topEnd: corner,
            bottomStart: isMe ? corner : Radius.zero,
            bottomEnd: isMe ? Radius.zero : corner,
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? AppColors.onPrimary : AppColors.heading,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              time,
              style: TextStyle(
                color: isMe
                    ? AppColors.onPrimary.withValues(alpha: .7)
                    : AppColors.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text field + send button at the bottom of the conversation.
class CustomerChatInput extends StatelessWidget {
  const CustomerChatInput({
    super.key,
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.xs,
        top: AppSpacing.xs,
        bottom: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.input,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'customer_chat.hint_message'.tr,
                hintStyle: AppTextStyles.input.copyWith(color: AppColors.hint),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: AppColors.primary,
            tooltip: 'customer_chat.btn_send'.tr,
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
