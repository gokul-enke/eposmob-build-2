import 'package:flutter/material.dart';
import '../../../models/restaurant/menu_item_model.dart';
import '../../../providers/app_settings_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';
import '../../../components/build_round_button.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class ModifierSelectionModal extends StatefulWidget {
  final MenuItemModel menuItem;
  final Function(Map<String, List<ModifierOption>>, String?)
      onModifiersSelected;

  const ModifierSelectionModal({
    super.key,
    required this.menuItem,
    required this.onModifiersSelected,
  });

  @override
  State<ModifierSelectionModal> createState() => _ModifierSelectionModalState();
}

class _ModifierSelectionModalState extends State<ModifierSelectionModal> {
  Map<String, List<ModifierOption>> _selectedModifiers = {};
  TextEditingController _notesController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Initialize with default modifiers if any
    for (var group in widget.menuItem.modifierGroups) {
      if (group.isRequired) {
        final defaultOption =
            group.options.firstWhereOrNull((opt) => opt.isDefault);
        if (defaultOption != null) {
          _selectedModifiers[group.id] = [defaultOption];
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _toggleModifierOption(String groupId, ModifierOption option) {
    setState(() {
      if (_selectedModifiers.containsKey(groupId)) {
        if (_selectedModifiers[groupId]!.contains(option)) {
          _selectedModifiers[groupId]!.remove(option);
          if (_selectedModifiers[groupId]!.isEmpty) {
            _selectedModifiers.remove(groupId);
          }
        } else {
          final group =
              widget.menuItem.modifierGroups.firstWhere((g) => g.id == groupId);
          if (group.maxSelections == 1) {
            _selectedModifiers[groupId] = [option];
          } else {
            _selectedModifiers[groupId]!.add(option);
          }
        }
      } else {
        _selectedModifiers[groupId] = [option];
      }
    });
  }

  double get _currentPrice {
    double price = widget.menuItem.price;
    for (final options in _selectedModifiers.values) {
      for (final opt in options) {
        price += opt.additionalPrice;
      }
    }
    return price;
  }

  bool _isValidSelection() {
    for (var group in widget.menuItem.modifierGroups) {
      if (group.isRequired && !_selectedModifiers.containsKey(group.id)) {
        return false;
      }
      if (group.isRequired && _selectedModifiers[group.id]!.isEmpty) {
        return false;
      }
      if (_selectedModifiers.containsKey(group.id) &&
          _selectedModifiers[group.id]!.length > group.maxSelections) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ColorManager.kBgLightColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(
        widget.menuItem.name,
        style: buildCustomStyle(
            FontWeightManager.bold, FontSize.s20, 0.3, ColorManager.textColor),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.menuItem.description,
              style: buildCustomStyle(FontWeightManager.regular, FontSize.s14,
                  0.21, ColorManager.textColor.withOpacity(0.7)),
            ),
            const SizedBox(height: 15),
            Consumer<AppSettingsProvider>(
              builder: (context, appSettingsProvider, child) {
                final currency =
                    appSettingsProvider.appSettings?.currency ?? 'INR';
                return Text(
                  '${'modifier_selection.base_price'.tr}$currency${widget.menuItem.price.toStringAsFixed(0)}',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s16, 0.23, ColorManager.kPrimaryColor),
                );
              },
            ),
            const Divider(height: 25, color: ColorManager.grey),
            if (widget.menuItem.modifierGroups.isNotEmpty)
              Text(
                'modifier_selection.customizations'.tr,
                style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                    0.3, ColorManager.textColor),
              ),
            const SizedBox(height: 10),
            ...widget.menuItem.modifierGroups.map((group) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 15.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${group.name} ${group.isRequired ? 'modifier_selection.required_label'.tr : 'modifier_selection.optional_label'.tr}',
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s14, 0.21, ColorManager.textColor),
                    ),
                    Text(
                      group.maxSelections == 1
                          ? '(Select ${'modifier_selection.select_one'.tr})'
                          : '(Select ${'modifier_selection.select_up_to_prefix'.tr}${group.maxSelections}${'modifier_selection.select_up_to_suffix'.tr})',
                      style: buildCustomStyle(FontWeightManager.regular,
                          FontSize.s12, 0.21, ColorManager.kGreyColor),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: group.options.map((option) {
                        final isSelected =
                            _selectedModifiers.containsKey(group.id) &&
                                _selectedModifiers[group.id]!.contains(option);
                        return ChoiceChip(
                          label: Consumer<AppSettingsProvider>(
                            builder: (context, appSettingsProvider, child) {
                              final currency =
                                  appSettingsProvider.appSettings?.currency ??
                                      'INR';
                              return Text(
                                '${option.name} ${option.additionalPrice > 0 ? '(+$currency${option.additionalPrice.toStringAsFixed(0)})' : ''}',
                              );
                            },
                          ),
                          selected: isSelected,
                          selectedColor: ColorManager.kPrimaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : ColorManager.textColor,
                          ),
                          onSelected: (selected) {
                            _toggleModifierOption(group.id, option);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Divider(height: 25, color: ColorManager.grey),
            Text(
              'modifier_selection.special_notes'.tr,
              style: buildCustomStyle(FontWeightManager.bold, FontSize.s16, 0.3,
                  ColorManager.textColor),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'modifier_selection.notes_hint'.tr,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 2,
            ),
            const Divider(height: 25, color: ColorManager.grey),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'modifier_selection.quantity'.tr,
                  style: buildCustomStyle(FontWeightManager.bold, FontSize.s16,
                      0.3, ColorManager.textColor),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: ColorManager.kButtonRed),
                      onPressed: () {
                        setState(() {
                          if (_quantity > 1) _quantity--;
                        });
                      },
                    ),
                    Text(
                      _quantity.toString(),
                      style: buildCustomStyle(FontWeightManager.semiBold,
                          FontSize.s16, 0.23, ColorManager.textColor),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: ColorManager.kButtonGreen),
                      onPressed: () {
                        setState(() {
                          _quantity++;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            Center(
              child: Consumer<AppSettingsProvider>(
                builder: (context, appSettingsProvider, child) {
                  final currency =
                      appSettingsProvider.appSettings?.currency ?? 'INR';
                  return Text(
                    '${'modifier_selection.total_price'.tr}$currency${(_currentPrice * _quantity).toStringAsFixed(0)}',
                    style: buildCustomStyle(FontWeightManager.bold,
                        FontSize.s22, 0.3, ColorManager.kPrimaryColor),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        CustomRoundButton(
          title: 'general.cancel'.tr,
          fct: () => Navigator.of(context).pop(),
          height: 40,
          width: 100,
          fontSize: FontSize.s14,
          boxColor: Colors.white,
          borderColor: ColorManager.kGreyColor,
          textColor: ColorManager.kGreyColor,
        ),
        CustomRoundButton(
          title: 'modifier_selection.btn_add_to_order'.tr,
          fct: _isValidSelection()
              ? () {
                  widget.onModifiersSelected(
                      _selectedModifiers,
                      _notesController.text.isNotEmpty
                          ? _notesController.text
                          : null);
                  Navigator.of(context).pop();
                }
              : () {},
          height: 40,
          width: 150,
          fontSize: FontSize.s14,
          boxColor: _isValidSelection()
              ? ColorManager.kButtonGreen
              : ColorManager.kGreyColor.withOpacity(0.5),
          borderColor: _isValidSelection()
              ? ColorManager.kButtonGreen
              : ColorManager.kGreyColor.withOpacity(0.5),
          textColor: Colors.white,
        ),
      ],
    );
  }
}

extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
