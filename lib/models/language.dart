class Language {
  final int id;
  final String name;
  final String code;
  final String type;
  final bool active;

  Language({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.active,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      type: json['type'] ?? 'ltr',
      active: json['active'] == 1 || json['active'] == true,
    );
  }

  bool get isRtl => type.toLowerCase() == 'rtl';
}
