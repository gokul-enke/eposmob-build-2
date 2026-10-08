import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pos_machine/models/document_configurations.dart';
import 'package:pos_machine/models/order_details.dart';
import 'package:pos_machine/providers/document_config_provider.dart';

DocumentConfig? resolveSalesPdfConfig(
  DocumentConfigProvider docConfigProvider,
  OrderDetailsModelData? orderData,
) {
  final hasReturns = orderData?.orderReturns != null &&
      orderData!.orderReturns!.returnItems != null &&
      orderData.orderReturns!.returnItems!.isNotEmpty;

  if (hasReturns) {
    return docConfigProvider.getDocumentConfig("Sales and Return Bill A4") ??
        docConfigProvider.getDocumentConfig("Sales and Return Bill") ??
        docConfigProvider.getDocumentConfig("Bill A4") ??
        docConfigProvider.getDocumentConfig("Bill");
  }

  return docConfigProvider.getDocumentConfig("Bill A4") ??
      docConfigProvider.getDocumentConfig("Bill");
}

DocumentConfig? resolveSalesReturnConfig(
  DocumentConfigProvider docConfigProvider,
  OrderDetailsModelData? orderData,
) {
  final hasReturns = orderData?.orderReturns?.returnItems?.isNotEmpty ?? false;
  if (!hasReturns) return null;
  return docConfigProvider.getDocumentConfig("Credit Note") ??
      docConfigProvider.getDocumentConfig("Return Bill");
}

Future<Directory> salesDocumentDirectory() async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final eposDirectory = Directory('${documentsDirectory.path}/epos');

  // Create epos directory if it doesn't exist
  if (!await eposDirectory.exists()) {
    await eposDirectory.create(recursive: true);
    debugPrint('Created epos directory: ${eposDirectory.path}');
  }

  return eposDirectory;
}
