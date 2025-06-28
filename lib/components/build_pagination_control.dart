import 'package:flutter/material.dart';

class PaginationControl extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const PaginationControl({
    Key? key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // DEBUG: Print pagination state
    debugPrint('=== PAGINATION CONTROL DEBUG ===');
    debugPrint('Current Page: $currentPage');
    debugPrint('Total Pages: $totalPages');
    debugPrint('Previous Button Enabled: ${currentPage > 1}');
    debugPrint('Next Button Enabled: ${currentPage < totalPages}');
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0, top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PaginationButton(
            title: "Previous",
            onPressed: currentPage > 1 ? () {
              debugPrint('Previous button pressed - going to page ${currentPage - 1}');
              onPageChanged(currentPage - 1);
            } : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Page $currentPage of $totalPages'),
          ),
          _PaginationButton(
            title: "Next",
            onPressed: currentPage < totalPages ? () {
              debugPrint('Next button pressed - going to page ${currentPage + 1}');
              onPageChanged(currentPage + 1);
            } : null,
          ),
        ],
      ),
    );
  }
}

class _PaginationButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;

  const _PaginationButton({
    Key? key,
    required this.title,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.blue,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 12),
      ),
      child: Text(title),
    );
  }
}
