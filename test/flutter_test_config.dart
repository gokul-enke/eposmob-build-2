import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pos_machine/resources/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  await LocalizationService.init();
  Get.addTranslations(LocalizationService.translations);
  Get.locale = const Locale('en');
  Get.fallbackLocale = LocalizationService.fallbackLocale;
  Get.testMode = true;

  await testMain();
}
