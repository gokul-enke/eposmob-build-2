import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/newcomponents/custom_dialog_box.dart';
import 'package:pos_machine/resources/app_url.dart';

import 'sales_document_files.dart';
import 'sales_page_services.dart';

Future<void> downloadSalesInvoice(BuildContext context,
    SalesPageServices services, String invoiceHash) async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    // URL of the PDF file
    final url = '${APPUrl.baseURL}/invoice-download/$invoiceHash';

    // Get the epos directory
    final eposDirectory = await salesDocumentDirectory();
    if (!context.mounted) return;

    // Create a file path for the PDF in the epos folder
    final filePath = '${eposDirectory.path}/invoice_$invoiceHash.pdf';

    // Configure Dio with options
    final dio = Dio();
    dio.options.validateStatus =
        (status) => status! < 500; // Don't throw on 4xx errors

    // Use Dio to download the file
    final response =
        await dio.download(url, filePath, onReceiveProgress: (received, total) {
      if (total != -1) {}
    });
    if (!context.mounted) return;

    // Close loading dialog
    Navigator.of(context, rootNavigator: true).pop();

    if (response.statusCode == 200) {
      showScaffold(
        context: context,
        message: 'sales.invoice_downloaded'
            .tr
            .replaceAll('@path', eposDirectory.path),
      );
    } else if (response.statusCode == 404) {
      showScaffoldError(
        context: context,
        message: 'sales.invoice_not_found'.tr,
      );
    } else {
      showScaffoldError(
        context: context,
        message: 'sales.failed_download_invoice'
            .tr
            .replaceAll('@code', response.statusCode.toString()),
      );
    }
  } catch (e) {
    // Close loading dialog if still showing
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    // More detailed error message based on error type
    String errorMessage = 'sales.err_download_file_default'.tr;
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'sales.err_connection_timeout'.tr;
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'sales.err_connection_error'.tr;
      } else if (e.response?.statusCode == 500) {
        errorMessage = 'sales.err_server_error'.tr;
      } else {
        errorMessage = 'sales.err_download_error'
            .tr
            .replaceAll('@message', e.message.toString());
      }
    } else {
      errorMessage =
          'sales.err_downloading_file'.tr.replaceAll('@error', e.toString());
    }

    showScaffoldError(
      context: context,
      message: errorMessage,
    );
  }
}
