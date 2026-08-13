import 'dart:convert';

enum CompanySubscriptionStatus { active, warning, blocked, unknown }

class CompanySubscription {
  const CompanySubscription({
    required this.status,
    required this.message,
    this.companyId,
    this.validUntil,
    this.manageSubscriptionUrl,
  });

  final int? companyId;
  final CompanySubscriptionStatus status;
  final String message;
  final DateTime? validUntil;
  final String? manageSubscriptionUrl;

  bool get permitsOrderSubmission =>
      status == CompanySubscriptionStatus.active ||
      status == CompanySubscriptionStatus.warning;

  factory CompanySubscription.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['subscription_status'] ?? json['status'];
    final status = _parseStatus(rawStatus?.toString());
    final message =
        (json['message'] ?? json['subscription_message'])?.toString().trim() ??
            '';
    final rawUrl =
        (json['manage_subscription_url'] ?? json['management_url'])?.toString();

    return CompanySubscription(
      companyId: _parseInt(json['company_id']),
      status: status,
      message: message.isNotEmpty ? message : _defaultMessage(status),
      validUntil: _parseDate(json['valid_until'] ?? json['end_date']),
      manageSubscriptionUrl:
          rawUrl == null || rawUrl.trim().isEmpty ? null : rawUrl.trim(),
    );
  }

  /// Accepts the preferred `data.subscription` response and the flat shape
  /// from the original product contract. This keeps login and refresh parsing
  /// identical while the backend rolls out the endpoint.
  static CompanySubscription? tryParsePayload(dynamic payload) {
    if (payload is! Map) return null;

    final root = payload.map((key, value) => MapEntry(key.toString(), value));
    final data = root['data'];
    final dataMap = data is Map
        ? data.map((key, value) => MapEntry(key.toString(), value))
        : root;
    final nested = dataMap['subscription'] ??
        dataMap['company_subscription'] ??
        root['subscription'] ??
        root['company_subscription'];
    final candidate = nested is Map
        ? nested.map((key, value) => MapEntry(key.toString(), value))
        : dataMap;

    if (!candidate.containsKey('subscription_status') &&
        !candidate.containsKey('status')) {
      return null;
    }

    // A top-level API `status: success` is not a subscription status.
    final rawStatus =
        candidate['subscription_status'] ?? candidate['status']?.toString();
    if (_parseStatus(rawStatus?.toString()) ==
            CompanySubscriptionStatus.unknown &&
        !candidate.containsKey('subscription_status')) {
      return null;
    }

    final enriched = <String, dynamic>{...candidate};
    enriched['company_id'] ??= dataMap['company_id'] ?? root['company_id'];
    return CompanySubscription.fromJson(enriched);
  }

  Map<String, dynamic> toJson() => {
        'company_id': companyId,
        'subscription_status': status.name,
        'message': message,
        'valid_until': validUntil?.toIso8601String(),
        'manage_subscription_url': manageSubscriptionUrl,
      };

  String encode() => jsonEncode(toJson());

  static CompanySubscription? decode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, dynamic>
          ? CompanySubscription.fromJson(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  CompanySubscription copyWith({
    CompanySubscriptionStatus? status,
    String? message,
    int? companyId,
    DateTime? validUntil,
    String? manageSubscriptionUrl,
  }) {
    return CompanySubscription(
      status: status ?? this.status,
      message: message ?? this.message,
      companyId: companyId ?? this.companyId,
      validUntil: validUntil ?? this.validUntil,
      manageSubscriptionUrl:
          manageSubscriptionUrl ?? this.manageSubscriptionUrl,
    );
  }

  static CompanySubscriptionStatus _parseStatus(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'active':
        return CompanySubscriptionStatus.active;
      case 'warning':
        return CompanySubscriptionStatus.warning;
      case 'blocked':
      case 'expired':
      case 'suspended':
      case 'inactive':
        return CompanySubscriptionStatus.blocked;
      default:
        return CompanySubscriptionStatus.unknown;
    }
  }

  static String _defaultMessage(CompanySubscriptionStatus status) {
    switch (status) {
      case CompanySubscriptionStatus.active:
        return '';
      case CompanySubscriptionStatus.warning:
        return 'Your company subscription requires attention. Please renew it to avoid interruption.';
      case CompanySubscriptionStatus.blocked:
        return 'Your company subscription is blocked. Renew it to continue creating orders.';
      case CompanySubscriptionStatus.unknown:
        return 'The company subscription status could not be verified.';
    }
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text);
  }
}
