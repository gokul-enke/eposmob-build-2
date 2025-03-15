class PaymentGateway {
  final int id;
  final String name;
  final String code;
  final String label;
  final String link;
  final String image;
  final String status;
  final int isWebActive;
  final int isAndroidActive;
  final int isIosActive;
  final String contactEmail;
  final String contactPhone;
  final String createdAt;
  final String updatedAt;

  PaymentGateway({
    required this.id,
    required this.name,
    required this.code,
    required this.label,
    required this.link,
    required this.image,
    required this.status,
    required this.isWebActive,
    required this.isAndroidActive,
    required this.isIosActive,
    required this.contactEmail,
    required this.contactPhone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentGateway.fromJson(Map<String, dynamic> json) {
    return PaymentGateway(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      label: json['label'],
      link: json['link'],
      image: json['image'],
      status: json['status'],
      isWebActive: json['is_web_active'],
      isAndroidActive: json['is_android_active'],
      isIosActive: json['is_ios_active'],
      contactEmail: json['contact_email'],
      contactPhone: json['contact_phone'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}