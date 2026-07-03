import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class CustomerChatWidget extends StatefulWidget {
  final Size size;
  final CustomerListModelData customer;

  const CustomerChatWidget({
    Key? key,
    required this.size,
    required this.customer,
  }) : super(key: key);

  @override
  State<CustomerChatWidget> createState() => _CustomerChatWidgetState();
}

class _CustomerChatWidgetState extends State<CustomerChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  bool isLoading = true;
  String? errorMessage;
  List<ChatMessage> messages = [];

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Simulate a network call
      await Future.delayed(const Duration(seconds: 1));

      // TODO: Replace with actual API call
      setState(() {
        messages = [
          ChatMessage(
            id: '1',
            text: 'Hello, I have a question about my last order.',
            time: '10:30 AM',
            isFromMe: false,
          ),
          ChatMessage(
            id: '2',
            text: 'Hi there! How can I help you today?',
            time: '10:31 AM',
            isFromMe: true,
          ),
          ChatMessage(
            id: '3',
            text: 'I was wondering about the warranty for my product.',
            time: '10:32 AM',
            isFromMe: false,
          ),
        ];
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = 'Failed to load chat history';
        isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final newMessage = ChatMessage(
      id: (messages.length + 1).toString(),
      text: text,
      time: '10:33 AM', // Replace with actual time
      isFromMe: true,
    );

    setState(() {
      messages.add(newMessage);
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
        margin: EdgeInsets.all(widget.size.width < 600 ? 10 : 24),
        padding: const EdgeInsets.all(0),
        height: widget.size.height * 0.75,
        width: widget.size.width / 1.8,
        circleRadius: 12,
        child: Column(
          children: [
            _buildChatHeader(),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? _buildErrorState()
                      : _buildChatInterface(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatHeader() {
    return Container(
      decoration: BoxDecoration(
        color: ColorManager.kPrimaryWithOpacity10,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: ColorManager.kPrimaryColor,
            child: Text(
              widget.customer.name![0],
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s18,
                0,
                Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer.name ?? 'Customer Name',
                  style: buildCustomStyle(
                    FontWeightManager.bold,
                    FontSize.s16,
                    0,
                    ColorManager.kTitleTextColor,
                  ),
                ),
                Text(
                  'Online',
                  style: buildCustomStyle(
                    FontWeightManager.regular,
                    FontSize.s12,
                    0,
                    ColorManager.kSuccessColor,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
            color: ColorManager.kGreyColor,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
              color: ColorManager.kRed,
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Chat',
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s18,
                0,
                ColorManager.kTitleTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'An unknown error occurred.',
              textAlign: TextAlign.center,
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0,
                ColorManager.kGreyColor,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadChatHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorManager.kPrimaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: false,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildChatBubble(messages[index]);
                  },
                ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.4),
          ),
          const SizedBox(height: 20),
          Text(
            'No Messages Yet',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s18,
              0,
              ColorManager.kTitleTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a conversation with ${widget.customer.name}.',
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0,
              ColorManager.kGreyColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isMe = message.isFromMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.45,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? ColorManager.kPrimaryColor
              : ColorManager.kPrimaryWithOpacity10,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft:
                isMe ? const Radius.circular(16) : const Radius.circular(0),
            bottomRight:
                isMe ? const Radius.circular(0) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : ColorManager.kTitleTextColor,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message.time,
              style: TextStyle(
                color: isMe ? Colors.white70 : ColorManager.kGreyColor,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          top: BorderSide(color: ColorManager.kBgDarkColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            color: ColorManager.kGreyColor,
            onPressed: () {},
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type your message here...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 8),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            color: ColorManager.kPrimaryColor,
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final String time;
  final bool isFromMe;

  ChatMessage({
    required this.id,
    required this.text,
    required this.time,
    required this.isFromMe,
  });
}
