import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/resources/app_url.dart';

typedef CategoryTaxGet = Future<http.Response> Function(Uri url,
    {Map<String, String>? headers});

/// The existing Add Category tax request, injectable without UI or providers.
class CategoryTaxSource {
  CategoryTaxSource({CategoryTaxGet? get}) : _get = get ?? http.get;
  final CategoryTaxGet _get;

  Future<http.Response?> fetch(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key') ?? '';
    if (token.isEmpty || apiKey.isEmpty) return null;
    return _get(
      Uri.parse('${APPUrl.listTax}?active_only=true'),
      headers: {
        'Authorization': 'Bearer $token',
        'X-Tenant': apiKey,
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));
  }
}
