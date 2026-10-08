import 'package:flutter/material.dart';

import '../../../state/day_close_form_controller.dart';

class DayCloseFormInputs {
  const DayCloseFormInputs(
      {required this.controller,
      required this.currency,
      required this.onClose});
  final DayCloseFormController controller;
  final String currency;
  final VoidCallback onClose;
}
