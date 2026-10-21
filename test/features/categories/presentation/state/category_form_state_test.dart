import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pos_machine/features/categories/data/category_tax_source.dart';
import 'package:pos_machine/features/categories/presentation/state/category_form_mixin.dart';
import 'package:pos_machine/models/language.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/language_provider.dart';
import 'package:pos_machine/resources/app_url.dart';

class _Auth extends AuthModel {
  @override
  String? get token => 'fixture-token';
}

class _Languages extends LanguageProvider {
  final translation = Completer<String?>();
  int calls = 0;
  @override
  Future<String?> translateText(
      {required String accessToken,
      required String targetLang,
      required String text}) {
    expect(accessToken, 'fixture-token');
    expect(targetLang, 'ar');
    expect(text, 'Category');
    calls++;
    return translation.future;
  }
}

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.source});
  final CategoryTaxSource source;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> with CategoryFormMixin<_Harness> {
  @override
  CategoryTaxSource get categoryTaxSource => widget.source;
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
  @override
  void dispose() {
    disposeCategoryForm();
    super.dispose();
  }
}

Future<_HarnessState> _mount(WidgetTester tester, CategoryTaxSource source,
    {_Languages? languages}) async {
  final key = GlobalKey<_HarnessState>();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthModel>(create: (_) => _Auth()),
      ChangeNotifierProvider<LanguageProvider>(
          create: (_) => languages ?? _Languages()),
    ],
    child:
        MaterialApp(home: Scaffold(body: _Harness(key: key, source: source))),
  ));
  return key.currentState!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() =>
      SharedPreferences.setMockInitialValues({'api_key': 'fixture-tenant'}));

  test('Tax request retains endpoint, active filter and authentication',
      () async {
    final source = CategoryTaxSource(get: (url, {headers}) async {
      expect(url.toString(), '${APPUrl.listTax}?active_only=true');
      expect(headers, {
        'Authorization': 'Bearer fixture-token',
        'X-Tenant': 'fixture-tenant',
        'Accept': 'application/json'
      });
      return http.Response('{"data":[]}', 200);
    });
    expect((await source.fetch('fixture-token'))!.statusCode, 200);
  });

  test('Missing token or tenant does not send a request', () async {
    int calls = 0;
    final source = CategoryTaxSource(get: (url, {headers}) async {
      calls++;
      return http.Response('{}', 200);
    });
    expect(await source.fetch(''), isNull);
    SharedPreferences.setMockInitialValues({});
    expect(await source.fetch('fixture-token'), isNull);
    expect(calls, 0);
  });

  testWidgets('Tax request still times out at ten seconds', (tester) async {
    final source = CategoryTaxSource(
        get: (url, {headers}) => Completer<http.Response>().future);
    final result = expectLater(
        source.fetch('fixture-token'), throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await result;
  });

  testWidgets('Tax loading parses flat data and retains selection',
      (tester) async {
    final state = await _mount(
        tester,
        CategoryTaxSource(
            get: (url, {headers}) async => http.Response(
                '{"data":[{"id":4,"name":"VAT"},{"id":5}]}', 200)));
    state.selectedTaxIds.add(4);
    await state.fetchTaxes();
    expect(state.availableTaxes.map((tax) => tax.id), [4, 5]);
    expect(state.availableTaxes.map((tax) => tax.name), ['VAT', '']);
    expect(state.selectedTaxIds, [4]);
    expect(state.taxesLoading, false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Failed and malformed tax responses preserve existing options',
      (tester) async {
    for (final response in [
      http.Response('{}', 500),
      http.Response('bad json', 200)
    ]) {
      final state = await _mount(
          tester, CategoryTaxSource(get: (url, {headers}) async => response));
      state.availableTaxes = [const CategoryTaxItem(id: 4, name: 'VAT')];
      await state.fetchTaxes();
      expect(state.availableTaxes.single.id, 4);
      expect(state.taxesLoading, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Tax completion after disposal does not update the form',
      (tester) async {
    final response = Completer<http.Response>();
    final state = await _mount(
        tester, CategoryTaxSource(get: (url, {headers}) => response.future));
    final result = state.fetchTaxes();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(http.Response('{"data":[{"id":4,"name":"VAT"}]}', 200));
    await result;
    expect(state.availableTaxes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Language aliases and dynamic controllers retain values across sync',
      (tester) async {
    final state = await _mount(tester, CategoryTaxSource());
    final languages = [
      Language(id: 1, name: 'English', code: 'en', type: 'ltr', active: true),
      Language(id: 2, name: 'Arabic', code: 'ar', type: 'rtl', active: true),
      Language(id: 3, name: 'Hindi', code: 'hi', type: 'ltr', active: true),
      Language(id: 4, name: 'French', code: 'fr', type: 'ltr', active: true),
    ];
    state.syncLanguageControllers(languages);
    expect(state.languageNameControllers[1],
        same(state.categoryNameEnglishController));
    expect(state.languageNameControllers[2],
        same(state.categoryNameArabicController));
    expect(state.languageNameControllers[3],
        same(state.categoryNameHindiController));
    final french = state.languageNameControllers[4]!;
    french.text = 'French name';
    state.syncLanguageControllers(languages);
    expect(state.languageNameControllers[4], same(french));
    expect(french.text, 'French name');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(() => french.addListener(() {}), throwsFlutterError);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Duplicate translation is suppressed and late result ignores disposal',
      (tester) async {
    final languages = _Languages();
    final state =
        await _mount(tester, CategoryTaxSource(), languages: languages);
    final arabic =
        Language(id: 2, name: 'Arabic', code: 'ar', type: 'rtl', active: true);
    state.syncLanguageControllers([arabic]);
    state.categoryNameController.text = ' Category ';
    final translation = state.translateLanguage(arabic);
    await state.translateLanguage(arabic);
    expect(languages.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    languages.translation.complete('Translated');
    await translation;
    expect(tester.takeException(), isNull);
  });
}
