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
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Select Dining Table'),
      content: SizedBox(
        width: 420,
        child: tables.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No tables available'),
              )
            : GridView.builder(
                shrinkWrap: true,
                itemCount: tables.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.8,
                ),
                itemBuilder: (context, index) {
                  final table = tables[index];
                  final isSelected = table.id == selectedTableId;
                  return OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onTableSelected(table);
                    },
                    icon: Icon(
                      Icons.table_restaurant_rounded,
                      color:
                          isSelected ? Colors.white : const Color(0xFF2563EB),
                    ),
                    label: Text(
                      table.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          isSelected ? const Color(0xFF2563EB) : Colors.white,
                      foregroundColor:
                          isSelected ? Colors.white : const Color(0xFF1E293B),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFFE2E8F0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
