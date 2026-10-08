import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/components/build_calendar_selection.dart';
import '../../../domain/quotation_list_query.dart';
import '../../state/quotation_list_controller.dart';

class QuotationFilterOption {
  const QuotationFilterOption(this.id, this.label);
  final String id, label;
}

FilterPanel quotationListFilters(QuotationListController controller,
    List<QuotationFilterOption> customers, List<QuotationFilterOption> stores) {
  CustomFilterField picker(
      String name,
      String label,
      String hint,
      IconData icon,
      String? id,
      List<QuotationFilterOption> options,
      void Function(String?) change) {
    final all = QuotationFilterOption('', hint);
    final items = <QuotationFilterOption>[
      all,
      ...{for (final item in options) item.id: item}.values
    ];
    final selected =
        items.firstWhereOrNull((option) => option.id == (id ?? '')) ??
            QuotationFilterOption(id!, '$label #$id');
    if (!items.any((option) => option.id == selected.id)) {
      items.add(selected);
    }
    return CustomFilterField(
        child: DropdownSearch<QuotationFilterOption>(
      key: ValueKey('quotation-$name-picker'),
      selectedItem: selected,
      compareFn: (a, b) => a.id == b.id,
      itemAsString: (item) => item.label,
      items: (_, __) => items,
      decoratorProps: DropDownDecoratorProps(
          baseStyle: AppTextStyles.input,
          decoration:
              AppInputDecoration.filter(label: label, hint: hint, icon: icon)),
      popupProps: PopupProps.menu(
          showSearchBox: true,
          constraints: const BoxConstraints(maxHeight: 320),
          menuProps: const MenuProps(backgroundColor: AppColors.surface),
          searchFieldProps: TextFieldProps(
              decoration: AppInputDecoration.filter(
                  label: label,
                  hint: 'quotations.list_search'.tr,
                  icon: Icons.search))),
      onChanged: (item) {
        change(item == null || item.id.isEmpty ? null : item.id);
        controller.search();
      },
    ));
  }

  CustomFilterField date(String name, String label, DateTime? value,
          void Function(DateTime?) change) =>
      CustomFilterField(
          child: Builder(
              builder: (context) => InkWell(
                  key: ValueKey('quotation-$name-date'),
                  onTap: () async {
                    final picked = await showAutoDismissDatePicker(
                        context: context,
                        initialDate: value ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (picked != null && context.mounted) {
                      change(picked);
                      controller.search();
                    }
                  },
                  child: InputDecorator(
                    decoration: AppInputDecoration.filter(
                        label: label,
                        icon: Icons.calendar_today_outlined,
                        suffix: value == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  change(null);
                                  controller.search();
                                })),
                    child: Text(
                        value == null
                            ? 'quotations.list_select_date'.tr
                            : QuotationListQuery.date(value),
                        style: value == null
                            ? AppTextStyles.sectionHint
                            : AppTextStyles.input),
                  ))));
  return FilterPanel(
      title: 'quotations.list_find'.tr,
      hint: 'quotations.list_filter_hint'.tr,
      resetLabel: 'list.reset'.tr,
      onReset: controller.reset,
      onSearch: controller.scheduleSearch,
      onSubmit: controller.search,
      fields: [
        TextFilterField(
            controller: controller.number,
            label: 'quotations.quotation_number_label'.tr,
            hint: 'quotations.search_hint'.tr,
            icon: Icons.search),
        picker(
            'customer',
            'quotations.customer_col'.tr,
            'quotations.select_customer'.tr,
            Icons.person_outline,
            controller.customerId,
            customers,
            (id) => controller.customerId = id),
        picker(
            'store',
            'quotations.store_col'.tr,
            'quotations.select_store'.tr,
            Icons.store_outlined,
            controller.storeId?.toString(),
            stores,
            (id) => controller.storeId = int.tryParse(id ?? '')),
        DropdownFilterField<String>(
            label: 'quotations.quotation_status'.tr,
            icon: Icons.flag_outlined,
            value: controller.status,
            options: [
              for (final status in ['All', 'Pending', 'Confirmed', 'Cancelled'])
                FilterOption(
                    status, 'quotations.status_${status.toLowerCase()}'.tr)
            ],
            onChanged: (status) {
              controller.status = status ?? 'All';
              controller.search();
            }),
        date(
            'quotation',
            'quotations.quotation_date'.tr,
            controller.quotationDate,
            (date) => controller.quotationDate = date),
        date('expiry', 'quotations.expiry_date'.tr, controller.expiryDate,
            (date) => controller.expiryDate = date),
      ]);
}
