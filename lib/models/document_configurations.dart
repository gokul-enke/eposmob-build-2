import 'dart:convert';
import 'package:flutter/material.dart';

DocumentConfigurationsModel documentConfigurationsModelFromJson(String str) =>
    DocumentConfigurationsModel.fromJson(json.decode(str));

String documentConfigurationsModelToJson(DocumentConfigurationsModel data) =>
    json.encode(data.toJson());

class DocumentConfigurationsModel {
  final String? status;
  final Map<String, DocumentConfig>? documentConfigurations;
  final DocumentOptions? options;

  DocumentConfigurationsModel({
    this.status,
    this.documentConfigurations,
    this.options,
  });

  factory DocumentConfigurationsModel.fromJson(Map<String, dynamic> json) =>
      DocumentConfigurationsModel(
        status: json["status"],
        documentConfigurations: json["document_configurations"] == null
            ? null
            : Map.from(json["document_configurations"]).map((k, v) =>
                MapEntry<String, DocumentConfig>(
                    k, DocumentConfig.fromJson(v))),
        options: json["options"] == null
            ? null
            : DocumentOptions.fromJson(json["options"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "document_configurations": documentConfigurations == null
            ? null
            : Map.from(documentConfigurations!)
                .map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
        "options": options?.toJson(),
      };
}

class DocumentConfig {
  final int? id;
  final int? companyId;
  final String? type;
  final dynamic logo; // Can be null
  final int? showLogo;
  final dynamic icon; // Can be null
  final int? showIcon;
  final String? numberPrefix;
  final dynamic discountMethod; // Can be null
  final String? header;
  final String? subheader;
  final String? terms;
  final String? footer;
  final String? accentColor;
  final dynamic font; // Can be null
  final String? template;
  final ItemName? itemName; // Nested object
  final ItemName? taxName; // Nested object, same structure
  final ItemName? unitName; // Nested object, same structure
  final ItemName? priceName; // Nested object, same structure
  final ItemName? amountName; // Nested object, same structure
  final dynamic createdBy; // Can be null
  final dynamic updatedBy; // Can be null
  final dynamic createdAt; // Can be null
  final String? updatedAt;
  final String? language; // Added language field
  final int? isActive;
  final String?
      activeTheme; // Theme identifier for layout selection (e.g., "classic", "modern", "minimal")
  final DisplayConfiguration? displayConfiguration; // Nested object
  final ResolvedLabels? resolvedLabels; // Nested object

  DocumentConfig({
    this.id,
    this.companyId,
    this.type,
    this.logo,
    this.showLogo,
    this.icon,
    this.showIcon,
    this.numberPrefix,
    this.discountMethod,
    this.header,
    this.subheader,
    this.terms,
    this.footer,
    this.accentColor,
    this.font,
    this.template,
    this.itemName,
    this.taxName,
    this.unitName,
    this.priceName,
    this.amountName,
    this.createdBy,
    this.updatedBy,
    this.createdAt,
    this.updatedAt,
    this.language, // Added to constructor
    this.isActive,
    this.activeTheme, // Theme identifier
    this.displayConfiguration,
    this.resolvedLabels,
  });

  factory DocumentConfig.fromJson(Map<String, dynamic> json) {
    var displayConfigJson = json["display_configuration"];
    displayConfigJson ??= _displayFlagsToDisplayConfiguration(
      json["display_flags"],
    );
    DisplayConfiguration? displayConfiguration;

    if (displayConfigJson is Map<String, dynamic>) {
      displayConfiguration = DisplayConfiguration.fromJson(displayConfigJson);
    }

    ItemName? parseItemName(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) {
        return ItemName.fromJson(raw);
      }
      if (raw is List) {
        // Some APIs send [] for these fields. Treat as not configured.
        return null;
      }
      return null;
    }

    ResolvedLabels? parseResolvedLabels(dynamic raw) {
      if (raw == null) return null;
      if (raw is Map<String, dynamic>) {
        return ResolvedLabels.fromJson(raw);
      }
      return null;
    }

    return DocumentConfig(
      id: json["id"],
      companyId: json["company_id"],
      type: json["type"],
      logo: json["logo"],
      showLogo: json["show_logo"],
      icon: json["icon"],
      showIcon: json["show_icon"],
      numberPrefix: json["number_prefix"],
      discountMethod: json["discount_method"],
      header: json["header"],
      subheader: json["subheader"],
      terms: json["terms"],
      footer: json["footer"],
      accentColor: json["accent_color"],
      font: json["font"],
      template: json["template"],
      itemName: parseItemName(json["item_name"]),
      taxName: parseItemName(json["tax_name"]),
      unitName: parseItemName(json["unit_name"]),
      priceName: parseItemName(json["price_name"]),
      amountName: parseItemName(json["amount_name"]),
      createdBy: json["created_by"],
      updatedBy: json["updated_by"],
      createdAt: json["created_at"],
      updatedAt: json["updated_at"],
      language: json["language"], // Parse language from JSON
      isActive: _parseIntegerFlag(json["is_active"]),
      activeTheme: json["active_theme"], // Parse active theme from JSON
      displayConfiguration: displayConfiguration,
      resolvedLabels: parseResolvedLabels(json["resolved_labels"]),
    );
  }

  static Map<String, dynamic>? _displayFlagsToDisplayConfiguration(
    dynamic raw,
  ) {
    if (raw is! Map) return null;

    return Map.from(raw).map(
      (key, value) => MapEntry<String, dynamic>(
        key.toString(),
        {
          'visible': value == true,
          'value': null,
        },
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "company_id": companyId,
        "type": type,
        "logo": logo,
        "show_logo": showLogo,
        "icon": icon,
        "show_icon": showIcon,
        "number_prefix": numberPrefix,
        "discount_method": discountMethod,
        "header": header,
        "subheader": subheader,
        "terms": terms,
        "footer": footer,
        "accent_color": accentColor,
        "font": font,
        "template": template,
        "item_name": itemName?.toJson(),
        "tax_name": taxName?.toJson(),
        "unit_name": unitName?.toJson(),
        "price_name": priceName?.toJson(),
        "amount_name": amountName?.toJson(),
        "created_by": createdBy,
        "updated_by": updatedBy,
        "created_at": createdAt,
        "updated_at": updatedAt,
        "language": language,
        "is_active": isActive,
        "active_theme": activeTheme,
        "display_configuration": displayConfiguration?.toJson(),
        "resolved_labels": resolvedLabels?.toJson(),
      };

  bool get isEnabled => isActive == null || isActive == 1;

  static int? _parseIntegerFlag(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

// This class is used for itemName, taxName, unitName, priceName, and amountName as they share the same structure
class ItemName {
  final String? option;

  ItemName({
    this.option,
  });

  factory ItemName.fromJson(Map<String, dynamic> json) => ItemName(
        option: json["option"],
      );

  Map<String, dynamic> toJson() => {
        "option": option,
      };
}

class DisplayConfiguration {
  final Map<String, DisplayOption>? options;

  DisplayConfiguration({
    this.options,
  });

  factory DisplayConfiguration.fromJson(Map<String, dynamic> json) {
    // The API response has display_configuration as a direct map of DisplayOptions
    // not nested under an "options" key
    if (json.isEmpty) {
      return DisplayConfiguration(options: null);
    }

    try {
      final options = Map.from(json).map((k, v) =>
          MapEntry<String, DisplayOption>(k, DisplayOption.fromJson(v)));

      return DisplayConfiguration(options: options);
    } catch (e) {
      debugPrint("❌ DisplayConfiguration.fromJson - error parsing: $e");
      return DisplayConfiguration(options: null);
    }
  }

  Map<String, dynamic> toJson() => {
        if (options != null)
          ...options!.map((k, v) => MapEntry<String, dynamic>(k, v.toJson())),
      };
}

class DisplayOption {
  final bool? visible;
  final dynamic value; // Can be String or null
  final String? defaultValue;

  DisplayOption({
    this.visible,
    this.value,
    this.defaultValue,
  });

  factory DisplayOption.fromJson(Map<String, dynamic> json) => DisplayOption(
        visible: _parseBooleanFlag(json["visible"]),
        value: json["value"],
        defaultValue: json["default"],
      );

  /// Accept the boolean encodings used by both the current API and older
  /// cached document configurations. Receipt renderers intentionally require
  /// an explicit `true`, so normalizing here prevents `1`/`"true"` from being
  /// treated as missing (or causing the complete options map to fail parsing).
  static bool? _parseBooleanFlag(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;

    switch (value.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
      default:
        return null;
    }
  }

  Map<String, dynamic> toJson() => {
        "visible": visible,
        "value": value,
        "default": defaultValue,
      };
}

class ResolvedLabels {
  final String? itemName;
  final String? unitName;
  final String? priceName;
  final String? taxName;
  final String? amountName;
  // Customer Statement specific fields
  final String? slNumber;
  final String? date;
  final String? orderNumber;
  final String? transactionType;
  final String? debit;
  final String? credit;
  final String? balance;
  final String? status;
  final String? tax;
  // Supplier Statement specific fields (aliased from 'item' in API)
  final String? item;
  // Bill specific fields
  final String? particulars;
  final String? mrp;
  final String? qty;
  final String? rate;
  final String? rateExcTax;
  final String? total;
  // Sales Return Bill specific fields
  final String? returnSlNumber;
  final String? returnParticulars;
  final String? returnMrp;
  final String? returnQty;
  final String? returnRate;
  final String? returnTotal;
  // Credit Note / Return Bill config fields
  final String? creditNoteNumber;
  final String? creditNoteDate;
  final String? creditNoteOrder;
  final String? creditNoteReason;
  final String? detailsHeading;
  final String? customerHeading;
  final String? itemsHeading;
  final String? creditNoteRefund;
  final String? creditNoteItemsCount;
  final String? creditNoteTotalAmount;
  final String? remarks;
  final String? signatory;
  // Default values for bilingual support (English defaults)
  final String? slNumberDefault;
  final String? particularsDefault;
  final String? mrpDefault;
  final String? qtyDefault;
  final String? rateDefault;
  final String? rateExcTaxDefault;
  final String? unitNameDefault;
  final String? totalDefault;
  final String? taxDefault;

  ResolvedLabels({
    this.itemName,
    this.unitName,
    this.priceName,
    this.taxName,
    this.amountName,
    this.slNumber,
    this.date,
    this.orderNumber,
    this.transactionType,
    this.debit,
    this.credit,
    this.balance,
    this.status,
    this.tax,
    this.item,
    this.particulars,
    this.mrp,
    this.qty,
    this.rate,
    this.rateExcTax,
    this.total,
    this.returnSlNumber,
    this.returnParticulars,
    this.returnMrp,
    this.returnQty,
    this.returnRate,
    this.returnTotal,
    this.creditNoteNumber,
    this.creditNoteDate,
    this.creditNoteOrder,
    this.creditNoteReason,
    this.detailsHeading,
    this.customerHeading,
    this.itemsHeading,
    this.creditNoteRefund,
    this.creditNoteItemsCount,
    this.creditNoteTotalAmount,
    this.remarks,
    this.signatory,
    this.slNumberDefault,
    this.particularsDefault,
    this.mrpDefault,
    this.qtyDefault,
    this.rateDefault,
    this.rateExcTaxDefault,
    this.unitNameDefault,
    this.totalDefault,
    this.taxDefault,
  });

  factory ResolvedLabels.fromJson(Map<String, dynamic> json) => ResolvedLabels(
        itemName: json["item_name"],
        unitName: json["unit_name"] ?? json["unit"],
        priceName: json["price_name"],
        taxName: json["tax_name"],
        amountName: json["amount_name"],
        slNumber: json["sl_number"],
        date: json["date"],
        orderNumber: json["order_number"],
        transactionType: json["transaction_type"],
        debit: json["debit"],
        credit: json["credit"],
        balance: json["balance"],
        status: json["status"],
        tax: json["tax"],
        item: json[
            "item"], // Supplier Statement uses 'item' instead of 'item_name'
        particulars: json["particulars"],
        mrp: json["mrp"],
        qty: json["qty"],
        rate: json["rate"],
        rateExcTax: json["rate_exc_tax"],
        total: json["total"],
        returnSlNumber: json["return_sl_number"],
        returnParticulars: json["return_particulars"],
        returnMrp: json["return_mrp"],
        returnQty: json["return_qty"],
        returnRate: json["return_rate"],
        returnTotal: json["return_total"],
        creditNoteNumber: json["credit_note_number"],
        creditNoteDate: json["credit_note_date"],
        creditNoteOrder: json["credit_note_order"],
        creditNoteReason: json["credit_note_reason"],
        detailsHeading: json["details_heading"],
        customerHeading: json["customer_heading"],
        itemsHeading: json["items_heading"],
        creditNoteRefund: json["credit_note_refund"],
        creditNoteItemsCount: json["credit_note_items_count"],
        creditNoteTotalAmount: json["credit_note_total_amount"],
        remarks: json["remarks"],
        signatory: json["signatory"],
        slNumberDefault: json["sl_number_default"],
        particularsDefault: json["particulars_default"],
        mrpDefault: json["mrp_default"],
        qtyDefault: json["qty_default"],
        rateDefault: json["rate_default"],
        rateExcTaxDefault: json["rate_exc_tax_default"],
        unitNameDefault: json["unit_name_default"] ?? json["unit_default"],
        totalDefault: json["total_default"],
        taxDefault: json["tax_default"],
      );

  Map<String, dynamic> toJson() => {
        "item_name": itemName,
        "unit_name": unitName,
        "price_name": priceName,
        "tax_name": taxName,
        "amount_name": amountName,
        "sl_number": slNumber,
        "date": date,
        "order_number": orderNumber,
        "transaction_type": transactionType,
        "debit": debit,
        "credit": credit,
        "balance": balance,
        "status": status,
        "tax": tax,
        "item": item,
        "particulars": particulars,
        "mrp": mrp,
        "qty": qty,
        "rate": rate,
        "rate_exc_tax": rateExcTax,
        "total": total,
        "return_sl_number": returnSlNumber,
        "return_particulars": returnParticulars,
        "return_mrp": returnMrp,
        "return_qty": returnQty,
        "return_rate": returnRate,
        "return_total": returnTotal,
        "credit_note_number": creditNoteNumber,
        "credit_note_date": creditNoteDate,
        "credit_note_order": creditNoteOrder,
        "credit_note_reason": creditNoteReason,
        "details_heading": detailsHeading,
        "customer_heading": customerHeading,
        "items_heading": itemsHeading,
        "credit_note_refund": creditNoteRefund,
        "credit_note_items_count": creditNoteItemsCount,
        "credit_note_total_amount": creditNoteTotalAmount,
        "remarks": remarks,
        "signatory": signatory,
        "sl_number_default": slNumberDefault,
        "particulars_default": particularsDefault,
        "mrp_default": mrpDefault,
        "qty_default": qtyDefault,
        "rate_default": rateDefault,
        "rate_exc_tax_default": rateExcTaxDefault,
        "unit_name_default": unitNameDefault,
        "total_default": totalDefault,
        "tax_default": taxDefault,
      };
}

class DocumentOptions {
  final Map<String, String>? itemNameOptions;
  final Map<String, String>? unitNameOptions;
  final Map<String, String>? priceNameOptions;
  final Map<String, String>? taxNameOptions;
  final Map<String, String>? amountNameOptions;
  final Map<String, String>? templateOptions;

  DocumentOptions({
    this.itemNameOptions,
    this.unitNameOptions,
    this.priceNameOptions,
    this.taxNameOptions,
    this.amountNameOptions,
    this.templateOptions,
  });

  factory DocumentOptions.fromJson(Map<String, dynamic> json) =>
      DocumentOptions(
        itemNameOptions: json["item_name_options"] == null
            ? null
            : Map.from(json["item_name_options"])
                .map((k, v) => MapEntry<String, String>(k, v)),
        unitNameOptions: json["unit_name_options"] == null
            ? null
            : Map.from(json["unit_name_options"])
                .map((k, v) => MapEntry<String, String>(k, v)),
        priceNameOptions: json["price_name_options"] == null
            ? null
            : Map.from(json["price_name_options"])
                .map((k, v) => MapEntry<String, String>(k, v)),
        taxNameOptions: json["tax_name_options"] == null
            ? null
            : Map.from(json["tax_name_options"])
                .map((k, v) => MapEntry<String, String>(k, v)),
        amountNameOptions: json["amount_name_options"] == null
            ? null
            : Map.from(json["amount_name_options"])
                .map((k, v) => MapEntry<String, String>(k, v)),
        templateOptions: json["template_options"] == null
            ? null
            : Map.from(json["template_options"])
                .map((k, v) => MapEntry<String, String>(k, v)),
      );

  Map<String, dynamic> toJson() => {
        "item_name_options": itemNameOptions == null
            ? null
            : Map.from(itemNameOptions!)
                .map((k, v) => MapEntry<String, dynamic>(k, v)),
        "unit_name_options": unitNameOptions == null
            ? null
            : Map.from(unitNameOptions!)
                .map((k, v) => MapEntry<String, dynamic>(k, v)),
        "price_name_options": priceNameOptions == null
            ? null
            : Map.from(priceNameOptions!)
                .map((k, v) => MapEntry<String, dynamic>(k, v)),
        "tax_name_options": taxNameOptions == null
            ? null
            : Map.from(taxNameOptions!)
                .map((k, v) => MapEntry<String, dynamic>(k, v)),
        "amount_name_options": amountNameOptions == null
            ? null
            : Map.from(amountNameOptions!)
                .map((k, v) => MapEntry<String, dynamic>(k, v)),
        "template_options": templateOptions == null
            ? null
            : Map.from(templateOptions!)
                .map((k, v) => MapEntry<String, dynamic>(k, v)),
      };
}
