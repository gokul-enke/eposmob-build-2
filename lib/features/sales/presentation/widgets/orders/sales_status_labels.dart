import 'package:get/get.dart';
import 'package:pos_machine/helpers/ui_code_labels.dart';

const salesStatusOptions = ['new', 'pending', 'confirmed', 'cancelled'];
String salesStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'new':
      return 'sales.status_new'.tr;
    case 'pending':
      return 'sales.status_pending'.tr;
    case 'confirmed':
      return 'sales.status_confirmed'.tr;
    case 'cancelled':
      return 'sales.status_cancelled'.tr;
    default:
      return UiCodeLabels.status(status);
  }
}
