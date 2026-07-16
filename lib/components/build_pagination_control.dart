import 'package:flutter/material.dart';

class PaginationControl extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const PaginationControl({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PaginationButton(
            title: "Previous",
            onPressed:
                currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Page $currentPage of $totalPages'),
          ),
          _PaginationButton(
            title: "Next",
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
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
    required this.title,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.blue,
            fontSize: 12,
            decoration: TextDecoration.underline,
            decorationColor: Colors.blue),
      ),
    );
  }
}
