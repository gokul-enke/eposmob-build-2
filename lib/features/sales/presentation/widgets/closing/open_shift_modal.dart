import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/core/ui/feedback/app_toast.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import '../../state/open_shift_form_controller.dart';
import '../../state/open_shift_form_ports.dart';
import 'open_shift_form/open_shift_form_inputs.dart';
import 'open_shift_form/open_shift_form_view.dart';

class OpenShiftModal extends StatefulWidget {
  final VoidCallback onSuccess;

  const OpenShiftModal({Key? key, required this.onSuccess}) : super(key: key);

  @override
  State<OpenShiftModal> createState() => _OpenShiftModalState();
}

class _OpenShiftModalState extends State<OpenShiftModal> {
  late final OpenShiftFormController controller;
  late final AppSettingsProvider settings;
  @override
  void initState() {
    super.initState();
    settings = context.read<AppSettingsProvider>();
    controller = OpenShiftFormController(
        ports: OpenShiftFormPorts.capture(context),
        onCompleted: () {
          if (!mounted) return;
          AppToast.success(context, 'daily_sales_close.msg_shift_opened'.tr);
          Navigator.of(context).pop();
          widget.onSuccess();
        });
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: Listenable.merge([controller, settings]),
      builder: (context, child) => OpenShiftFormView(
          inputs: OpenShiftFormInputs(
              controller: controller,
              currency: settings.appSettings?.currency ?? 'INR',
              onClose: () => Navigator.of(context).pop())));
}
