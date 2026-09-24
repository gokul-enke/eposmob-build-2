import 'package:flutter/material.dart';
import 'package:get/get.dart';

Widget showEmptyMessege({String? message, TextStyle? style}) {
  return Center(
    child: Text(
      message ?? 'general.no_items_found'.tr,
      style: style ??
          const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
    ),
  );
}
