import 'package:flutter/material.dart';
import 'package:pos_machine/models/restaurant/table_model.dart';

class DiningSelectionModal extends StatelessWidget {
  final List<TableModel> tables;
  final String? selectedTableId;
  final ValueChanged<TableModel> onTableSelected;

  const DiningSelectionModal({
    super.key,
    required this.tables,
    required this.selectedTableId,
    required this.onTableSelected,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.72).clamp(760.0, 1080.0);
    final dialogHeight = (screenSize.height * 0.78).clamp(560.0, 760.0);
    final indoorTables = tables.where((table) => table.section == 1).toList();
    final outdoorTables = tables.where((table) => table.section != 1).toList();

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: tables.isEmpty
                  ? const Center(child: Text('No tables available'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                      child: Column(
                        children: [
                          if (indoorTables.isNotEmpty)
                            _buildSection(
                              title: 'INDOOR',
                              tables: indoorTables,
                            ),
                          if (indoorTables.isNotEmpty &&
                              outdoorTables.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Divider(height: 1),
                            ),
                          if (outdoorTables.isNotEmpty)
                            _buildSection(
                              title: 'OUTDOOR',
                              tables: outdoorTables,
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 18, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          const Text(
            'Table List',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),
          _buildLegendItem('Available', const Color(0xFF111827)),
          _buildLegendItem('Reserved', const Color(0xFF2563EB)),
          _buildLegendItem('Filled', const Color(0xFFCBD5E1)),
          _buildLegendItem('Available soon', const Color(0xFFF2C94C)),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<TableModel> tables,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = constraints.maxWidth >= 760 ? 98.0 : 88.0;
            return Wrap(
              spacing: 22,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: tables
                  .map(
                    (table) => SizedBox(
                      width: table.capacity >= 6 ? tileWidth * 1.65 : tileWidth,
                      child: _buildTableTile(context, table),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTableTile(BuildContext context, TableModel table) {
    final isSelected = table.id == selectedTableId;
    final statusColor =
        isSelected ? const Color(0xFF2563EB) : _statusColor(table.status);
    final textColor =
        _usesLightText(statusColor) ? Colors.white : const Color(0xFF111827);
    final isLongTable = table.capacity >= 6;

    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTableSelected(table);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChairRow(statusColor, isLongTable ? 5 : 2),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 34,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(5),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: statusColor.withOpacity(0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                table.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildChairRow(statusColor, isLongTable ? 5 : 2),
          ],
        ),
      ),
    );
  }

  Widget _buildChairRow(Color color, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
        count,
        (_) => Container(
          width: 16,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Color _statusColor(TableStatus status) {
    switch (status) {
      case TableStatus.available:
        return const Color(0xFF111827);
      case TableStatus.occupied:
        return const Color(0xFFCBD5E1);
      case TableStatus.reserved:
        return const Color(0xFF2563EB);
      case TableStatus.cleaning:
      case TableStatus.maintenance:
        return const Color(0xFFF2C94C);
    }
  }

  bool _usesLightText(Color color) {
    return color == const Color(0xFF111827) || color == const Color(0xFF2563EB);
  }
}
