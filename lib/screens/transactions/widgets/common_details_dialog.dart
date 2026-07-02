import 'package:flutter/material.dart';
import '../../../../resources/color_manager.dart';
import '../../../../resources/font_manager.dart';
import '../../../../resources/style_manager.dart';
import '../../../../components/build_round_button.dart';

class CommonDetailsDialog extends StatelessWidget {
  final String title;
  final List<List<Widget>> gridColumns;
  final String? sectionTitle;
  final Widget? tableContent;
  final Widget? totalsContent; // Optional persistent totals footer content
  final List<Widget>? extraActions;

  const CommonDetailsDialog({
    Key? key,
    required this.title,
    required this.gridColumns,
    this.sectionTitle,
    this.tableContent,
    this.totalsContent,
    this.extraActions,
  }) : super(key: key);

  static Widget buildKeyValueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160, // Gives a consistent gap and aligns values vertically like a table
            child: Text(
              "$label:",
              style: buildCustomStyle(
                FontWeightManager.semiBold,
                FontSize.s14,
                0.19,
                Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s14,
                0.19,
                Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 650;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        width: screenWidth * 0.8, // 80% width on smaller screens
        constraints: BoxConstraints(
          minHeight: 480, // Minimum height to make the box taller and spacious
          maxWidth: 800, // Caps width to prevent excessive stretch on wide desktop monitors
          maxHeight: screenHeight * 0.85, // Responsive height constraint
        ),
        padding: EdgeInsets.zero, // Zero margin at parent so header spans full width
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Blue Title Banner (Spans the entire top edge)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: ColorManager.kPrimaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), // Matches dialog top rounded corners
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: buildCustomStyle(
                        FontWeightManager.bold,
                        FontSize.s22, // Bigger font size for heading as requested
                        0.25,
                        Colors.white, // White text
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // 2. Dialog Body Content & Actions (Padded)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(28.0), // Generous padding for content area
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Scrollable content area
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Grid Fields (Adjusts side-by-side or stacked based on width)
                            if (isNarrow)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: gridColumns.expand((columnWidgets) {
                                  return columnWidgets;
                                }).toList(),
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: gridColumns.map((columnWidgets) {
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: columnWidgets,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                            // Section Title (if provided)
                            if (sectionTitle != null) ...[
                              const SizedBox(height: 32),
                              Text(
                                sectionTitle!,
                                style: buildCustomStyle(
                                  FontWeightManager.bold,
                                  FontSize.s16,
                                  0.20,
                                  Colors.black, // Plain black heading colour
                                ),
                              ),
                            ],

                            // Table Content (if provided)
                            if (tableContent != null) ...[
                              const SizedBox(height: 16),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 400), // Increased max height so more items are visible
                                child: SingleChildScrollView(
                                  child: tableContent!,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Persistent Totals Content (if provided)
                    if (totalsContent != null) ...[
                      totalsContent!,
                      const SizedBox(height: 16),
                    ],

                    // 4. Actions Row (Fixed at bottom-right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (extraActions != null) ...extraActions!,
                        if (extraActions != null) const SizedBox(width: 12),
                        CustomRoundButton(
                          title: "Close",
                          boxColor: ColorManager.kPrimaryColor,
                          textColor: Colors.white,
                          fct: () => Navigator.pop(context),
                          height: 40,
                          width: 120,
                          fontSize: FontSize.s12,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
