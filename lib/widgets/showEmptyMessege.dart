import 'package:flutter/material.dart';

Widget showEmptyMessege({String message = 'No items found', TextStyle? style}) {
  return Center(
    child: Text(
      message,
      style: style ??
          const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
    ),
  );
}
