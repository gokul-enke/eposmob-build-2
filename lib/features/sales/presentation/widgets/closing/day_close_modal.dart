import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/features/sales/domain/models/day_close_pending_status.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:provider/provider.dart';

import '../../state/day_close_form_controller.dart';
import '../../state/day_close_form_ports.dart';
import 'day_close_form/day_close_form_inputs.dart';
import 'day_close_form/day_close_form_view.dart';

class DayCloseModal extends StatefulWidget {
  final VoidCallback onSuccess;
  final OpenDraftModel? openDraft;
  final String? pendingBusinessDate;
  final int? pendingOpeningTransactionId;
  final int? pendingClosingTransactionId;

  const DayCloseModal({
    super.key,
    required this.onSuccess,
    this.openDraft,
    this.pendingBusinessDate,
    this.pendingOpeningTransactionId,
    this.pendingClosingTransactionId,
  });

  @override
  State<DayCloseModal> createState() => _DayCloseModalState();
}

class _DayCloseModalState extends State<DayCloseModal> {
  late final DayCloseFormController controller;
  late final AppSettingsProvider settings;
  @override
  void initState() {
    super.initState();
    settings = context.read<AppSettingsProvider>();
    controller = DayCloseFormController(
        ports: DayCloseFormPorts.capture(context),
        openDraft: widget.openDraft,
        pendingBusinessDate: widget.pendingBusinessDate,
        pendingOpeningTransactionId: widget.pendingOpeningTransactionId,
        pendingClosingTransactionId: widget.pendingClosingTransactionId,
        onCompleted: (message) {
          if (!mounted) return;
          Navigator.of(context).pop();
          showScaffold(context: context, message: message);
          widget.onSuccess();
        },
        onError: (message) {
          if (mounted) showScaffoldError(context: context, message: message);
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
      builder: (context, child) => DayCloseFormView(
          inputs: DayCloseFormInputs(
              controller: controller,
              currency: settings.appSettings?.currency ?? 'INR',
              onClose: () => Navigator.of(context).pop())));
}
