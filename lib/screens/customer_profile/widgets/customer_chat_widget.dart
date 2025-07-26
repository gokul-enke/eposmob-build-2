import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/models/customer_list.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      });

      // Get API key from SharedPreferences
      // SharedPreferences prefs = await SharedPreferences.getInstance();
      // String? apiKey = prefs.getString('api_key');

      // if (apiKey == null || apiKey.isEmpty) {
      //   throw const HttpException("API key not found. Please restart the app.");
      // }
      // TODO: Replace with actual API call to get chat history
      // final response = await http.get(
      //   Uri.parse('${APPUrl.getCustomerChat}/${widget.customer.id}'),
      //   headers: {
      //     'Authorization': 'Bearer $accessToken',
      //     'Content-Type': 'application/json',
      //     'X-Tenant': apiKey,
      //   },
      // );

      // For now, just set empty messages
      setState(() {
        messages = [];
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

    // TODO: Implement actual message sending
    // final response = await http.post(
    //   Uri.parse('${APPUrl.sendCustomerChat}'),
    //   headers: {
    //     'Authorization': 'Bearer $accessToken',
    //     'Content-Type': 'application/json',
    //   },
    //   body: jsonEncode({
    //     'customer_id': widget.customer.id,
    //     'message': text,
    //   }),
    // );

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BuildBoxShadowContainer(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      height: widget.size.height * 0.75,
      width: widget.size.width / 1.8,
      circleRadius: 7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Chat',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s20,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 20),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.withOpacity(0.7),
          ),
          const SizedBox(height: 20),
          Text(
            'Error Loading Chat',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            errorMessage ?? 'An unknown error occurred',
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.30,
              ColorManager.blackWithOpacity50,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadChatHistory,
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorManager.kPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
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
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    return _buildChatBubble(message);
                  },
                ),
        ),
        const SizedBox(height: 16),
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
            Icons.chat_bubble_outline,
            size: 60,
            color: ColorManager.kPrimaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'No Messages Yet',
            style: buildCustomStyle(
              FontWeightManager.semiBold,
              FontSize.s16,
              0.30,
              ColorManager.textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start a conversation with this customer',
            textAlign: TextAlign.center,
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s14,
              0.30,
              ColorManager.blackWithOpacity50,
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
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.4,
        ),
        decoration: BoxDecoration(
          color: isMe ? ColorManager.kPrimaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.5,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: ColorManager.kPrimaryColor,
            onPressed: () {
              // TODO: Implement file attachment
            },
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
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
