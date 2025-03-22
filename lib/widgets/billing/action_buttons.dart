import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onClearCart;
  final VoidCallback onSaveOrder;
  final VoidCallback onCreateOrderAndPrint;
  final VoidCallback onConfirmOrder;
  final bool isLoadingClearCart;
  final bool isLoadingSaveOrder;
  final bool isLoadingCreateOrder;
  final bool isLoadingConfirmOrder;

  const ActionButtons({
    Key? key,
    required this.onClearCart,
    required this.onSaveOrder,
    required this.onCreateOrderAndPrint,
    required this.onConfirmOrder,
    required this.isLoadingClearCart,
    required this.isLoadingSaveOrder,
    required this.isLoadingCreateOrder,
    required this.isLoadingConfirmOrder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            text: 'Clear Cart',
            color: const Color(0xFFFF6961), // Red
            onPressed: onClearCart,
            isLoading: isLoadingClearCart,
          ),
          _buildActionButton(
            text: 'Save Order',
            color: const Color(0xFFFFD700), // Yellow
            onPressed: onSaveOrder,
            isLoading: isLoadingSaveOrder,
          ),
          _buildActionButton(
            text: 'Create Order and Print',
            color: const Color(0xFF1E90FF), // Blue
            onPressed: onCreateOrderAndPrint,
            isLoading: isLoadingCreateOrder,
          ),
          _buildActionButton(
            text: 'Confirm Order',
            color: const Color(0xFF32CD32), // Green
            onPressed: onConfirmOrder,
            isLoading: isLoadingConfirmOrder,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: GestureDetector(
          onTap: isLoading ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              color: color,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
} 