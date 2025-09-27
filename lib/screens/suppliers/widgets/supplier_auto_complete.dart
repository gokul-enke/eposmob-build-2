import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';

class SupplierAutocomplete extends StatefulWidget {
  final Size size;
  final List<String> supplierList;
  final TextEditingController controller;
  final Function(String) onSelected;

  const SupplierAutocomplete({
    Key? key,
    required this.size,
    required this.supplierList,
    required this.controller,
    required this.onSelected,
  }) : super(key: key);

  @override
  State<SupplierAutocomplete> createState() => _SupplierAutocompleteState();
}

class _SupplierAutocompleteState extends State<SupplierAutocomplete> {
  List<String> filteredSuppliers = [];
  bool showSuggestions = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    filteredSuppliers = widget.supplierList;
    
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() {
          showSuggestions = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _filterSuppliers(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredSuppliers = widget.supplierList;
        showSuggestions = false;
      } else {
        filteredSuppliers = widget.supplierList
            .where((supplier) =>
                supplier.toLowerCase().contains(query.toLowerCase()))
            .toList();
        showSuggestions = filteredSuppliers.isNotEmpty;
      }
    });
  }

  void _selectSupplier(String supplier) {
    widget.controller.text = supplier;
    widget.onSelected(supplier);
    setState(() {
      showSuggestions = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BuildBoxShadowContainer(
          height: 45,
          width: double.infinity,
          circleRadius: 7,
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: (value) {
              _filterSuppliers(value);
              if (value.isEmpty) {
                widget.onSelected('');
              }
            },
            onTap: () {
              if (widget.controller.text.isNotEmpty) {
                _filterSuppliers(widget.controller.text);
              }
            },
            decoration: InputDecoration(
              hintText: "Search Supplier",
              hintStyle: buildCustomStyle(
                FontWeightManager.regular,
                FontSize.s12,
                0.27,
                ColorManager.textColor.withOpacity(.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 12,
              ),
              suffixIcon: widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        widget.controller.clear();
                        widget.onSelected('');
                        setState(() {
                          showSuggestions = false;
                          filteredSuppliers = widget.supplierList;
                        });
                      },
                    )
                  : const Icon(
                      Icons.search,
                      color: ColorManager.kPrimaryColor,
                      size: 18,
                    ),
            ),
            style: buildCustomStyle(
              FontWeightManager.regular,
              FontSize.s12,
              0.27,
              ColorManager.textColor,
            ),
          ),
        ),
        if (showSuggestions && filteredSuppliers.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: BuildBoxShadowContainer(
              margin: const EdgeInsets.only(top: 2),
              circleRadius: 7,
              color: Colors.white,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredSuppliers.length > 10 
                    ? 10 
                    : filteredSuppliers.length,
                itemBuilder: (context, index) {
                  final supplier = filteredSuppliers[index];
                  return ListTile(
                    dense: true,
                    title: Text(
                      supplier,
                      style: buildCustomStyle(
                        FontWeightManager.regular,
                        FontSize.s12,
                        0.27,
                        ColorManager.textColor,
                      ),
                    ),
                    onTap: () => _selectSupplier(supplier),
                    hoverColor: ColorManager.kPrimaryColor.withOpacity(0.1),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}