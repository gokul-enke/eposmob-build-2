import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import '../../domain/general_payment_type.dart';

/// What New Entry opens with: the type to start on (the list's Entry type
/// filter) and each reference series' expected next number, by prefix.
typedef GeneralPaymentCreateRequest = ({
  GeneralPaymentType? type,
  Map<String, String> nextReferences,
});

/// The one place that knows how General Payments is reached in the sidebar
/// shell.
abstract final class GeneralPaymentNavigation {
  static SideBarController get _sidebar => Get.isRegistered<SideBarController>()
      ? Get.find<SideBarController>()
      : Get.put(SideBarController());

  /// Screens of the Accounts menu (highlighted while one is shown).
  static const sectionIndices = {
    SideBarController.generalPaymentListScreenIndex,
    SideBarController.generalPaymentCreateScreenIndex,
  };

  static GeneralPaymentCreateRequest? _createRequest;

  static void openList() =>
      _sidebar.index.value = SideBarController.generalPaymentListScreenIndex;

  /// New Entry. The sidebar's screens take no arguments, so [type] and
  /// [nextReferences] wait here for the page to take them.
  static void openCreate(
      {GeneralPaymentType? type,
      Map<String, String> nextReferences = const {}}) {
    _createRequest = (type: type, nextReferences: nextReferences);
    _sidebar.index.value = SideBarController.generalPaymentCreateScreenIndex;
  }

  /// What the last [openCreate] asked for, once; null when New Entry was not
  /// opened from the list.
  static GeneralPaymentCreateRequest? takeCreateRequest() {
    final request = _createRequest;
    _createRequest = null;
    return request;
  }
}
