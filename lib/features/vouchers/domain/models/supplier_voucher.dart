class SupplierVoucher {
  final int id;
  final String voucherNumber;
  final String voucherDate;
  final String dueDate;
  final String amount;
  final String status;
  final String type;
  final String paymentMethod;
  final SupplierData supplier;
  final List<VoucherItemData> items;

  SupplierVoucher({
    required this.id,
    required this.voucherNumber,
    required this.voucherDate,
    required this.dueDate,
    required this.amount,
    required this.status,
    required this.type,
    required this.paymentMethod,
    required this.supplier,
    required this.items,
  });

  factory SupplierVoucher.fromJson(Map<String, dynamic> json) {
    return SupplierVoucher(
      id: json['id'] ?? 0,
      voucherNumber: json['voucher_number'] ?? '',
      voucherDate: json['voucher_date'] ?? '',
      dueDate: json['due_date'] ?? '',
      amount: json['amount']?.toString() ?? '0',
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      supplier: SupplierData.fromJson(json['supplier'] ?? {}),
      items: (json['items'] as List?)
              ?.map((item) => VoucherItemData.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SupplierData {
  final int id;
  final String name;
  final String email;
  final String phone;

  SupplierData({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory SupplierData.fromJson(Map<String, dynamic> json) {
    final user = json['user'] ?? {};
    return SupplierData(
      id: json['id'] ?? 0,
      name: user['name'] ?? '',
      email: user['email'] ?? '',
      phone: user['phone'] ?? '',
    );
  }
}

class VoucherItemData {
  final int id;
  final String itemName;
  final String quantity;
  final String unitAmount;
  final String tax;
  final String totalAmount;

  VoucherItemData({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.unitAmount,
    required this.tax,
    required this.totalAmount,
  });

  factory VoucherItemData.fromJson(Map<String, dynamic> json) {
    return VoucherItemData(
      id: json['id'] ?? 0,
      itemName: json['item_name'] ?? '',
      quantity: json['quantity']?.toString() ?? '0',
      unitAmount: json['unit_amount']?.toString() ?? '0',
      tax: json['tax']?.toString() ?? '0',
      totalAmount: json['total_amount']?.toString() ?? '0',
    );
  }
}

class SupplierVoucherModel {
  final String status;
  final String message;
  final List<SupplierVoucher> data;
  final int currentPage;
  final int lastPage;

  SupplierVoucherModel({
    required this.status,
    required this.message,
    required this.data,
    required this.currentPage,
    required this.lastPage,
  });

  factory SupplierVoucherModel.fromJson(Map<String, dynamic> json) {
    final responseData = json['data'];
    final List<dynamic> voucherData;
    int currentPage = 1;
    int lastPage = 1;

    if (responseData is List) {
      voucherData = responseData;
    } else if (responseData is Map<String, dynamic>) {
      voucherData = responseData['data'] is List ? responseData['data'] : [];
      currentPage = _parseInt(responseData['current_page'], fallback: 1);
      lastPage = _parseInt(responseData['last_page'], fallback: currentPage);
    } else {
      voucherData = [];
    }

    return SupplierVoucherModel(
      status: json['status'] ?? '',
      message: json['message'] ?? '',
      data: voucherData
          .whereType<Map<String, dynamic>>()
          .map((item) => SupplierVoucher.fromJson(item))
          .toList(),
      currentPage: currentPage,
      lastPage: lastPage,
    );
  }

  static int _parseInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
