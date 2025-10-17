import 'dart:convert';

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
  final DisplayConfiguration? displayConfiguration; // Nested object
  final ResolvedLabels? resolvedLabels; // Nested object

  DocumentConfig({
    this.id,
    this.companyId,
    this.type,
    this.logo,
    this.showLogo,
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
    this.displayConfiguration,
    this.resolvedLabels,
  });

  factory DocumentConfig.fromJson(Map<String, dynamic> json) {
    var displayConfigJson = json["display_configuration"];
    DisplayConfiguration? displayConfiguration;

    if (displayConfigJson is Map<String, dynamic>) {
      displayConfiguration = DisplayConfiguration.fromJson(displayConfigJson);
    }

    return DocumentConfig(
      id: json["id"],
      companyId: json["company_id"],
      type: json["type"],
      logo: json["logo"],
      showLogo: json["show_logo"],
      numberPrefix: json["number_prefix"],
      discountMethod: json["discount_method"],
      header: json["header"],
      subheader: json["subheader"],
      terms: json["terms"],
      footer: json["footer"],
      accentColor: json["accent_color"],
      font: json["font"],
      template: json["template"],
      itemName: json["item_name"] == null
          ? null
          : ItemName.fromJson(json["item_name"]),
      taxName: json["tax_name"] == null
          ? null
          : ItemName.fromJson(json["tax_name"]),
      unitName: json["unit_name"] == null
          ? null
          : ItemName.fromJson(json["unit_name"]),
      priceName: json["price_name"] == null
          ? null
          : ItemName.fromJson(json["price_name"]),
      amountName: json["amount_name"] == null
          ? null
          : ItemName.fromJson(json["amount_name"]),
      createdBy: json["created_by"],
      updatedBy: json["updated_by"],
      createdAt: json["created_at"],
      updatedAt: json["updated_at"],
      displayConfiguration: displayConfiguration,
      resolvedLabels: json["resolved_labels"] == null
          ? null
          : ResolvedLabels.fromJson(json["resolved_labels"]),
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "company_id": companyId,
        "type": type,
        "logo": logo,
        "show_logo": showLogo,
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
        "display_configuration": displayConfiguration?.toJson(),
        "resolved_labels": resolvedLabels?.toJson(),
      };
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
      print("❌ DisplayConfiguration.fromJson - error parsing: $e");
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

  DisplayOption({
    this.visible,
    this.value,
  });

  factory DisplayOption.fromJson(Map<String, dynamic> json) => DisplayOption(
        visible: json["visible"],
        value: json["value"],
      );

  Map<String, dynamic> toJson() => {
        "visible": visible,
        "value": value,
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
  final String? total;
  // Sales Return Bill specific fields
  final String? returnSlNumber;
  final String? returnParticulars;
  final String? returnMrp;
  final String? returnQty;
  final String? returnRate;
  final String? returnTotal;

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
    this.total,
    this.returnSlNumber,
    this.returnParticulars,
    this.returnMrp,
    this.returnQty,
    this.returnRate,
    this.returnTotal,
  });

  factory ResolvedLabels.fromJson(Map<String, dynamic> json) => ResolvedLabels(
        itemName: json["item_name"],
        unitName: json["unit_name"],
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
        item: json["item"], // Supplier Statement uses 'item' instead of 'item_name'
        particulars: json["particulars"],
        mrp: json["mrp"],
        qty: json["qty"],
        rate: json["rate"],
        total: json["total"],
        returnSlNumber: json["return_sl_number"],
        returnParticulars: json["return_particulars"],
        returnMrp: json["return_mrp"],
        returnQty: json["return_qty"],
        returnRate: json["return_rate"],
        returnTotal: json["return_total"],
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
        "total": total,
        "return_sl_number": returnSlNumber,
        "return_particulars": returnParticulars,
        "return_mrp": returnMrp,
        "return_qty": returnQty,
        "return_rate": returnRate,
        "return_total": returnTotal,
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
