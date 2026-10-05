import 'package:pos_machine/features/sales/presentation/sharing/sales_page_services.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/document_config_provider.dart';

DocumentConfig? resolveDetailPdfConfig(
  DocumentConfigProvider docConfigProvider,
  OrderDetailsModelData? orderDetailsModelData,
) {
  final hasReturns = orderDetailsModelData?.orderReturns != null &&
      orderDetailsModelData!.orderReturns!.returnItems != null &&
      orderDetailsModelData.orderReturns!.returnItems!.isNotEmpty;

  if (hasReturns) {
    return docConfigProvider.getDocumentConfig("Sales and Return Bill A4") ??
        docConfigProvider.getDocumentConfig("Sales and Return Bill") ??
        docConfigProvider.getDocumentConfig("Bill A4") ??
        docConfigProvider.getDocumentConfig("Bill");
  }

  return docConfigProvider.getDocumentConfig("Bill A4") ??
      docConfigProvider.getDocumentConfig("Bill");
}

DocumentConfig? resolveDetailReturnConfig(
  DocumentConfigProvider docConfigProvider,
  OrderDetailsModelData? orderDetailsModelData,
) {
  final hasReturns =
      orderDetailsModelData?.orderReturns?.returnItems?.isNotEmpty ?? false;
  if (!hasReturns) return null;
  return docConfigProvider.getDocumentConfig("Credit Note") ??
      docConfigProvider.getDocumentConfig("Return Bill");
}

bool isDetailDefaultCustomerPhone(String? phone, SalesPageServices services) {
  if (phone == null || phone.isEmpty) return false;
  final appSettingsProvider = services.settings;
  final defaultPhone =
      appSettingsProvider.appSettings?.autoAssignDefaultCustomerPhone ?? "";
  return defaultPhone.isNotEmpty && phone == defaultPhone;
}
