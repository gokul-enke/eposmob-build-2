import 'package:flutter/material.dart';

class BuildMultiSelectDropDownWithSearch<T> extends StatefulWidget {
  final String hintText;
  final List<T> items;
  final List<T> selectedItems;
  final String Function(T) displayText;
  final Function(List<T>) onChanged;

  const BuildMultiSelectDropDownWithSearch({
    Key? key,
    required this.hintText,
    required this.items,
    required this.selectedItems,
    required this.displayText,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<BuildMultiSelectDropDownWithSearch<T>> createState() =>
      _BuildMultiSelectDropDownWithSearchState<T>();
}

class _BuildMultiSelectDropDownWithSearchState<T>
    extends State<BuildMultiSelectDropDownWithSearch<T>> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = "";

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _filter = _searchController.text.toLowerCase());
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = widget.items
        .where((item) =>
            widget.displayText(item).toLowerCase().contains(_filter))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: widget.hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
          child: InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) {
                  return StatefulBuilder(
                    builder: (ctx, setModalState) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: "Search...",
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: ListView.builder(
                                itemCount: filteredItems.length,
                                itemBuilder: (ctx, index) {
                                  final item = filteredItems[index];
                                  final isSelected =
                                      widget.selectedItems.contains(item);

                                  return CheckboxListTile(
                                    title: Text(widget.displayText(item)),
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setModalState(() {
                                        final updated = List<T>.from(
                                            widget.selectedItems);
                                        if (checked == true) {
                                          updated.add(item);
                                        } else {
                                          updated.remove(item);
                                        }
                                        widget.onChanged(updated);
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
            child: Wrap(
              spacing: 6,
              children: widget.selectedItems.isEmpty
                  ? [const Text("Tap to select")]
                  : widget.selectedItems
                      .map((e) => Chip(
                            label: Text(widget.displayText(e)),
                            onDeleted: () {
                              setState(() {
                                final updated =
                                    List<T>.from(widget.selectedItems);
                                updated.remove(e);
                                widget.onChanged(updated);
                              });
                            },
                          ))
                      .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
