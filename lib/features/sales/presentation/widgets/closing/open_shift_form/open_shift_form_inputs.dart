import 'package:flutter/material.dart';

import '../../../state/open_shift_form_controller.dart';

class OpenShiftFormInputs {
  const OpenShiftFormInputs(
      {required this.controller,
      required this.currency,
      required this.onClose});
  final OpenShiftFormController controller;
  final String currency;
  final VoidCallback onClose;
}
