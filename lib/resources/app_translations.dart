import 'package:get/get.dart';

class AppTranslations extends Translations {
  final Map<String, Map<String, String>> maps;
  AppTranslations(this.maps);

  @override
  Map<String, Map<String, String>> get keys => maps;
}
