import 'dart:convert';

ListTransactionModel listTransactionModelFromJson(String str) =>
    ListTransactionModel.fromJson(json.decode(str));

String listTransactionModelToJson(ListTransactionModel data) =>
    json.encode(data.toJson());

class ListTransactionModel {
  final String? status;
  final String? message;
  final TransactionData? data;

  ListTransactionModel({
    this.status,
    this.message,
    this.data,
  });

  factory ListTransactionModel.fromJson(Map<String, dynamic> json) =>
      ListTransactionModel(
        status: json["status"],
        message: json["message"],
        data: json["data"] == null
            ? null
            : TransactionData.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "status": status,
        "message": message,
        "data": data?.toJson(),
      };
}

class TransactionData {
  final int? currentPage;
  final List<ListTransaction>?
      transactions; // Renamed to transactions for clarity
  final String? firstPageUrl;
  final int? from;
  final int? lastPage;
  final String? lastPageUrl;
  final List<Link>? links;
  final String? nextPageUrl;
  final String? path;
  final int? perPage;
  final String? prevPageUrl;
  final int? to;
  final int? total;

  TransactionData({
    this.currentPage,
    this.transactions,
    this.firstPageUrl,
    this.from,
    this.lastPage,
    this.lastPageUrl,
    this.links,
    this.nextPageUrl,
    this.path,
    this.perPage,
    this.prevPageUrl,
    this.to,
    this.total,
  });

  factory TransactionData.fromJson(Map<String, dynamic> json) =>
      TransactionData(
        currentPage: json["current_page"],
        transactions: json["data"] == null
            ? []
            : List<ListTransaction>.from(
                json["data"].map((x) => ListTransaction.fromJson(x))),
        firstPageUrl: json["first_page_url"],
        from: json["from"],
        lastPage: json["last_page"],
        lastPageUrl: json["last_page_url"],
        links: json["links"] == null
            ? []
            : List<Link>.from(json["links"].map((x) => Link.fromJson(x))),
        nextPageUrl: json["next_page_url"],
        path: json["path"],
        perPage: json["per_page"],
        prevPageUrl: json["prev_page_url"],
        to: json["to"],
        total: json["total"],
      );

  Map<String, dynamic> toJson() => {
        "current_page": currentPage,
        "data": transactions == null
            ? []
            : List<dynamic>.from(transactions!.map((x) => x.toJson())),
        "first_page_url": firstPageUrl,
        "from": from,
        "last_page": lastPage,
        "last_page_url": lastPageUrl,
        "links": links == null
            ? []
            : List<dynamic>.from(links!.map((x) => x.toJson())),
        "next_page_url": nextPageUrl,
        "path": path,
        "per_page": perPage,
        "prev_page_url": prevPageUrl,
        "to": to,
        "total": total,
      };
}

class ListTransaction {
  final int? id;
  final int? orderId;
  final String? paymentMethod;
  final String? date; // Changed to String since it's just a date
  final String? type;
  final String? referenceId; // Changed from reference to reference_id
  final String? transactionType; // Changed from type to transaction_type
  final String? amount;
  final String? currency;
  final String? reference;
  final String? transactionComment; // Kept as is
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? orderNumber;
  final String? customerName;
  ListTransaction({
    this.id,
    this.orderId,
    this.paymentMethod,
    this.date,
    this.type,
    this.referenceId,
    this.transactionType,
    this.amount,
    this.currency,
    this.reference,
    this.transactionComment,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.customerName,
    this.orderNumber,
  });

  factory ListTransaction.fromJson(Map<String, dynamic> json) =>
      ListTransaction(
        id: json["id"],
        orderId: json["order_id"],
        paymentMethod: _parsePaymentMethod(json["payment_method"]),
        date: json["date"], // Keeps the date as a string
        type: json["type"],
        referenceId:
            json["reference_id"], // Changed from reference to reference_id
        transactionType:
            json["transaction_type"], // Changed from type to transaction_type
        amount: json["amount"],
        currency: json["currency"],
        reference: json["reference"],
        transactionComment: json["transaction_comment"],
        status: json["status"],
        orderNumber: json["order_number"],
        createdAt: json["created_at"] == null
            ? null
            : DateTime.parse(json["created_at"]),
        updatedAt: json["updated_at"] == null
            ? null
            : DateTime.parse(json["updated_at"]),
        customerName: json["customer_name"],
      );

  // Helper method to handle payment_method which can be String or List<String>
  static String? _parsePaymentMethod(dynamic paymentMethod) {
    if (paymentMethod == null) return null;
    if (paymentMethod is String) return paymentMethod;
    if (paymentMethod is List && paymentMethod.isNotEmpty) {
      return paymentMethod.join(', ');
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "order_id": orderId,
        "payment_method": paymentMethod,
        "date": date,
        "type": type,
        "reference_id": referenceId, // Changed from reference to reference_id
        "transaction_type":
            transactionType, // Changed from type to transaction_type
        "amount": amount,
        "currency": currency,
        "reference": reference,
        "transaction_comment": transactionComment,
        "status": status,
        "created_at": createdAt?.toIso8601String(),
        "updated_at": updatedAt?.toIso8601String(),
        "customer_name": customerName,
      };
}

class Link {
  final String? url;
  final String? label;
  final bool? active;

  Link({
    this.url,
    this.label,
    this.active,
  });

  factory Link.fromJson(Map<String, dynamic> json) => Link(
        url: json["url"],
        label: json["label"],
        active: json["active"],
      );

  Map<String, dynamic> toJson() => {
        "url": url,
        "label": label,
        "active": active,
      };
}
