import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/ui.dart';
import 'package:pos_machine/models/list_transaction.dart';
import 'customer_ledger_labels.dart';
import 'package:intl/intl.dart';
import '../state/customer_ledger_list_controller.dart';

class CustomerLedgerFilters {
  CustomerLedgerFilters(this.controller,
      {required this.onPickDate,
      required this.dateFieldKey,
      required this.mobileKey,
      required this.desktopKey});
  final CustomerLedgerListController controller;
  final VoidCallback onPickDate;
  final Key dateFieldKey, mobileKey, desktopKey;
  FilterFieldDef _customerField() => CustomFilterField(
      child: RawAutocomplete<ListTransaction>(
          textEditingController: controller.name,
          focusNode: controller.nameFocus,
          displayStringForOption: (r) => r.customerName ?? '',
          optionsBuilder: (value) {
            final ids = <int?>{};
            return controller.suggestions.where((r) =>
                (r.customerName?.isNotEmpty ?? false) &&
                (r.customerName!)
                    .toLowerCase()
                    .contains(value.text.toLowerCase()) &&
                ids.add(r.customerId));
          },
          onSelected: controller.selectCustomer,
          fieldViewBuilder: (_, textController, focus, submit) => TextField(
              controller: textController,
              focusNode: focus,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              style: AppTextStyles.input,
              decoration: AppInputDecoration.filter(
                  label: 'party_accounts.customer_name'.tr,
                  icon: Icons.person_outline),
              onChanged: (_) => controller.editCustomer(),
              onSubmitted: (_) => controller.search.flush()),
          optionsViewBuilder: (_, select, options) => Align(
              alignment: AlignmentDirectional.topStart,
              child: Material(
                  elevation: 4,
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                  child: SizedBox(
                      width: 280,
                      height: 200,
                      child: ListView(children: [
                        for (final r in options)
                          ListTile(
                              title: Text(r.customerName ?? ''),
                              onTap: () => select(r))
                      ]))))));

  FilterFieldDef _dateField() => CustomFilterField(
      child: InkWell(
          key: dateFieldKey,
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onPickDate,
          child: InputDecorator(
              textAlignVertical: TextAlignVertical.center,
              decoration: AppInputDecoration.filter(
                  label: 'party_accounts.date'.tr,
                  icon: Icons.calendar_today_outlined),
              child: Text(
                  controller.date == null
                      ? 'party_accounts.select_date'.tr
                      : DateFormat('MMM dd, yyyy').format(controller.date!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.input))));

  FilterPanel build(bool mobile) => FilterPanel(
          key: mobile ? mobileKey : desktopKey,
          title: 'party_accounts.find'.tr,
          hint: 'party_accounts.filter_hint'.tr,
          resetLabel: 'list.reset'.tr,
          onSearch: controller.search.schedule,
          onSubmit: controller.search.flush,
          onReset: controller.reset,
          fields: [
            TextFilterField(
                controller: controller.amount,
                label: 'party_accounts.amount'.tr,
                hint: 'party_accounts.amount'.tr,
                icon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true)),
            _customerField(),
            DropdownFilterField<String>(
                label: 'party_accounts.type'.tr,
                icon: Icons.swap_vert,
                value: controller.type,
                options: [
                  for (final t in ['All', 'Credit', 'Debit'])
                    FilterOption(
                        t, t == 'All' ? 'common.all'.tr : ledgerTypeLabel(t)),
                ],
                onChanged: controller.selectType),
            TextFilterField(
                controller: controller.reference,
                label: 'party_accounts.reference_id'.tr,
                hint: 'party_accounts.reference_id'.tr,
                icon: Icons.tag),
            _dateField(),
          ]);
}
