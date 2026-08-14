import 'package:flutter/material.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:get/get.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/screens/settings/widgets/settings_responsive.dart';

import '../../controllers/whatsapp_controller.dart';

class WhatsappSettingsScreen extends StatelessWidget {
  const WhatsappSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(WhatsappController(), permanent: true);
    final sideBarController = Get.find<SideBarController>();

    return SettingsPageShell(
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SettingsSubPageHeader(
            backLabel: 'whatsapp_settings.back_label'.tr,
            onBack: () {
              sideBarController.index.value =
                  62; // Navigate back to Settings
            },
            onClose: () {
              sideBarController.index.value =
                  62; // Navigate back to Settings
            },
            title: 'whatsapp_settings.title'.tr,
            subtitle: 'whatsapp_settings.subtitle'.tr,
          ),
          const SizedBox(height: 20),
          SettingsContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Obx(() => SettingsStatusBadge(
                          label: ctrl.connected.value
                              ? 'whatsapp_settings.status_connected'.tr
                              : 'whatsapp_settings.status_disconnected'.tr,
                          isPositive: ctrl.connected.value,
                          icon: ctrl.connected.value
                              ? Icons.check_circle
                              : Icons.error_outline,
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                Obx(() {
                  final qr = ctrl.qrCode.value;
                  final isConnecting = ctrl.isConnecting.value;
                  final connected = ctrl.connected.value;

                  if (connected) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF25D366).withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF25D366),
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'whatsapp_settings.connected_title'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.semiBold,
                              FontSize.s16,
                              0.24,
                              const Color(0xFF128C7E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'whatsapp_settings.connected_subtitle'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s13,
                              0.19,
                              const Color(0xFF128C7E),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Text(
                        'whatsapp_settings.scan_instruction'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s14,
                          0.21,
                          ColorManager.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'whatsapp_settings.scan_steps'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s12,
                          0.18,
                          Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: SizedBox(
                            height: 200,
                            width: 200,
                            child: qr.isNotEmpty
                                ? PrettyQrView.data(
                                    data: qr,
                                    decoration: const PrettyQrDecoration(
                                      shape: PrettyQrSmoothSymbol(
                                        color: Color(0xFF25D366),
                                      ),
                                    ),
                                    errorCorrectLevel: QrErrorCorrectLevel.M,
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isConnecting) ...[
                                        const CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Color(0xFF25D366),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'whatsapp_settings.qr_generating'.tr,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s14,
                                            0.21,
                                            const Color(0xFF25D366),
                                          ),
                                        ),
                                      ] else ...[
                                        Icon(
                                          Icons.qr_code_2,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'whatsapp_settings.qr_idle'.tr,
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s13,
                                            0.19,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 20),
                Obx(() {
                  final connectButton = ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ctrl.connected.value
                          ? Colors.grey.shade400
                          : const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: ctrl.isConnecting.value || ctrl.connected.value
                        ? null
                        : () => ctrl.connect(),
                    icon: ctrl.isConnecting.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.link, size: 18),
                    label: Text(
                      ctrl.isConnecting.value
                          ? 'whatsapp_settings.btn_connecting'.tr
                          : ctrl.connected.value
                              ? 'whatsapp_settings.btn_connected'.tr
                              : 'whatsapp_settings.btn_connect'.tr,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );

                  final disconnectButton = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: ctrl.connected.value
                        ? () => ctrl.disconnect()
                        : null,
                    icon: const Icon(Icons.link_off, size: 18),
                    label: Text(
                      'whatsapp_settings.btn_disconnect'.tr,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );

                  final isCompact = MediaQuery.of(context).size.width <
                      kSettingsPhoneBreakpoint;

                  if (isCompact) {
                    return SettingsActionRow(
                      children: [
                        SizedBox(
                            width: double.infinity, child: connectButton),
                        SizedBox(
                            width: double.infinity, child: disconnectButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: connectButton),
                      const SizedBox(width: 12),
                      Expanded(child: disconnectButton),
                    ],
                  );
                }),
                Obx(() => ctrl.error.value.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ctrl.error.value,
                                style: buildCustomStyle(
                                  FontWeightManager.medium,
                                  FontSize.s12,
                                  0.18,
                                  Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsContentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSectionHeader(
                  title: 'whatsapp_settings.test_message_title'.tr,
                  subtitle: 'whatsapp_settings.test_message_subtitle'.tr,
                ),
                const SizedBox(height: 16),
                _PhoneAndMessageForm(ctrl: ctrl),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SettingsContentCard(
            child: Obx(() => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'whatsapp_settings.auto_reconnect_title'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.medium,
                              FontSize.s14,
                              0.20,
                              ColorManager.textColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'whatsapp_settings.auto_reconnect_subtitle'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s12,
                              0.18,
                              Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: ctrl.autoReconnect.value,
                      onChanged: (value) {
                        ctrl.toggleAutoReconnect();
                        showScaffold(
                          context: context,
                          message: ctrl.autoReconnect.value
                              ? 'whatsapp_settings.auto_reconnect_enabled'.tr
                              : 'whatsapp_settings.auto_reconnect_disabled'.tr,
                        );
                      },
                      activeColor: const Color(0xFF25D366),
                    ),
                  ],
                )),
          ),
        ],
      ),
    );
  }
}

class _PhoneAndMessageForm extends StatefulWidget {
  final WhatsappController ctrl;
  const _PhoneAndMessageForm({required this.ctrl});

  @override
  State<_PhoneAndMessageForm> createState() => _PhoneAndMessageFormState();
}

class _PhoneAndMessageFormState extends State<_PhoneAndMessageForm> {
  final _phone = TextEditingController();
  final _msg = TextEditingController(text: 'Hello from CloudPOS');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phone.dispose();
    _msg.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _phone,
            decoration: InputDecoration(
              labelText: 'whatsapp_settings.field_phone'.tr,
              hintText: '+91xxxxxxxxxx',
              prefixIcon: const Icon(Icons.phone),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'whatsapp_settings.validator_phone'.tr : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _msg,
            decoration: InputDecoration(
              labelText: 'whatsapp_settings.field_message'.tr,
              prefixIcon: const Icon(Icons.message),
            ),
            maxLines: 2,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'whatsapp_settings.validator_message'.tr : null,
          ),
          const SizedBox(height: 16),
          Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: widget.ctrl.connected.value
                      ? () {
                          if (_formKey.currentState?.validate() ?? false) {
                            widget.ctrl.sendTestMessage(
                                _phone.text.trim(), _msg.text.trim());
                          }
                        }
                      : null,
                  icon: const Icon(Icons.send, size: 18),
                  label: Text('whatsapp_settings.btn_send_test'.tr),
                ),
              )),
        ],
      ),
    );
  }
}
