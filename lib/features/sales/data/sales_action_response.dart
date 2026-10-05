import 'dart:convert';

import 'package:pos_machine/helpers/api_response_helper.dart';

import '../domain/sales_action_error.dart';

class SalesActionResponse {
  static void ensureSalesActionSucceeded(
    int statusCode,
    String responseBody, {
    required String fallback,
  }) {
    if (statusCode == 200 || statusCode == 201) {
      try {
        final decoded = json.decode(responseBody);
        if (decoded is Map) {
          final rawStatus = decoded['status'];
          final status = rawStatus?.toString().toLowerCase();
          final rawSuccess = decoded['success'];
          final success = rawSuccess?.toString().toLowerCase();
          if (rawStatus == false ||
              rawStatus == 0 ||
              rawSuccess == false ||
              rawSuccess == 0 ||
              status == 'false' ||
              status == 'failed' ||
              status == 'error' ||
              status == 'failure' ||
              success == 'false') {
            throw SalesApiException(
              ApiResponseHelper.messageFromBody(
                responseBody,
                fallback: fallback,
              ),
            );
          }
        }
      } on FormatException {
        // Some successful endpoints return an empty or non-JSON response.
      }
      return;
    }

    throw SalesApiException(
      ApiResponseHelper.messageFromBody(
        responseBody,
        fallback: fallback,
      ),
    );
  }

  static String apiErrorMessage(
    Object error, {
    required String fallback,
  }) {
    if (error is SalesApiException && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return fallback;
  }
}
