import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:get/get.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:pos_machine/components/build_dialog_box.dart';

import '../../controllers/whatsapp_controller.dart';

class WhatsappSettingsScreen extends StatelessWidget {
  const WhatsappSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(WhatsappController(), permanent: true);
    final sideBarController = Get.find<SideBarController>();

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: ColorManager.boxShadowColor,
              blurRadius: 6,
              offset: Offset(1, 1),
            ),
          ],
          color: Colors.white,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomBackButton(
                    onPressed: () {
                      sideBarController.index.value =
                          62; // Navigate back to Settings
                    },
                    text: 'Settings',
                  ),
                  BuildBoxShadowContainer(
                    width: 15,
                    height: 15,
                    circleRadius: 10,
                    color: ColorManager.kPrimaryColor,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        sideBarController.index.value =
                            62; // Navigate back to Settings
                      },
                      icon: const Icon(Icons.close_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
              Text(
                'WhatsApp Integration',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // WhatsApp Connection Card
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Text(
                                //   'WhatsApp Connection',
                                //   style: buildCustomStyle(
                                //     FontWeightManager.semiBold,
                                //     FontSize.s18,
                                //     0.27,
                                //     ColorManager.textColor,
                                //   ),
                                // ),
                                Obx(() => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: ctrl.connected.value
                                            ? const Color(0xFF25D366)
                                                .withOpacity(0.15)
                                            : Colors.red.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: ctrl.connected.value
                                              ? const Color(0xFF25D366)
                                              : Colors.red,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            ctrl.connected.value
                                                ? Icons.check_circle
                                                : Icons.error_outline,
                                            size: 16,
                                            color: ctrl.connected.value
                                                ? const Color(0xFF128C7E)
                                                : Colors.red,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            ctrl.connected.value
                                                ? 'Connected'
                                                : 'Disconnected',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ctrl.connected.value
                                                  ? const Color(0xFF128C7E)
                                                  : Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // QR Code or Connected State
                            Obx(() {
                              final qr = ctrl.qrCode.value;
                              final isConnecting = ctrl.isConnecting.value;
                              final connected = ctrl.connected.value;

                              if (connected) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFF25D366)
                                          .withOpacity(0.3),
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
                                        'WhatsApp Connected Successfully',
                                        style: buildCustomStyle(
                                          FontWeightManager.semiBold,
                                          FontSize.s16,
                                          0.24,
                                          const Color(0xFF128C7E),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ready to send invoices and receipts',
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
                                    'Scan QR code with WhatsApp on your phone',
                                    style: buildCustomStyle(
                                      FontWeightManager.regular,
                                      FontSize.s14,
                                      0.21,
                                      ColorManager.textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Go to WhatsApp > Settings > Linked Devices > Link a Device',
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
                                                decoration:
                                                    const PrettyQrDecoration(
                                                  shape: PrettyQrSmoothSymbol(
                                                    color: Color(0xFF25D366),
                                                  ),
                                                ),
                                                errorCorrectLevel:
                                                    QrErrorCorrectLevel.M,
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (isConnecting) ...[
                                                    const CircularProgressIndicator(
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Color(
                                                                  0xFF25D366)),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      'Generating QR Code...',
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
                                                        FontSize.s14,
                                                        0.21,
                                                        const Color(0xFF25D366),
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    Icon(
                                                      Icons.qr_code_2,
                                                      size: 64,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      'Click Connect to generate QR code',
                                                      style: buildCustomStyle(
                                                        FontWeightManager
                                                            .medium,
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

                            // Action Buttons
                            Obx(() => Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: ctrl.connected.value
                                              ? Colors.grey.shade400
                                              : const Color(0xFF25D366),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: ctrl.isConnecting.value ||
                                                ctrl.connected.value
                                            ? null
                                            : () => ctrl.connect(),
                                        icon: ctrl.isConnecting.value
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white),
                                                ),
                                              )
                                            : const Icon(Icons.link, size: 18),
                                        label: Text(
                                          ctrl.isConnecting.value
                                              ? 'Connecting...'
                                              : ctrl.connected.value
                                                  ? 'Connected'
                                                  : 'Connect',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(
                                              color: Colors.red),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        onPressed: ctrl.connected.value
                                            ? () => ctrl.disconnect()
                                            : null,
                                        icon: const Icon(Icons.link_off,
                                            size: 18),
                                        label: const Text(
                                          'Disconnect',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                )),

                            // Error Display
                            Obx(() => ctrl.error.value.isEmpty
                                ? const SizedBox.shrink()
                                : Container(
                                    margin: const EdgeInsets.only(top: 16),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.red.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline,
                                            color: Colors.red.shade600,
                                            size: 20),
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

                      // Test Message Card
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Test Message',
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s16,
                                0.24,
                                ColorManager.textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Send a test message to verify WhatsApp integration.',
                              style: buildCustomStyle(
                                FontWeightManager.regular,
                                FontSize.s12,
                                0.18,
                                Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _PhoneAndMessageForm(ctrl: ctrl),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Settings Card
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settings',
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s16,
                                0.24,
                                ColorManager.textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Obx(() => Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Auto-Reconnect',
                                          style: buildCustomStyle(
                                            FontWeightManager.medium,
                                            FontSize.s14,
                                            0.20,
                                            ColorManager.textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Automatically reconnect when connection is lost',
                                          style: buildCustomStyle(
                                            FontWeightManager.regular,
                                            FontSize.s12,
                                            0.18,
                                            Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Switch(
                                      value: ctrl.autoReconnect.value,
                                      onChanged: (value) {
                                        ctrl.toggleAutoReconnect();
                                        showScaffold(
                                          context: context,
                                          message: ctrl.autoReconnect.value
                                              ? 'Auto-Reconnect enabled'
                                              : 'Auto-Reconnect disabled',
                                        );
                                      },
                                      activeColor: const Color(0xFF25D366),
                                    ),
                                  ],
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+91xxxxxxxxxx',
              prefixIcon: Icon(Icons.phone),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter phone number' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _msg,
            decoration: const InputDecoration(
              labelText: 'Message',
              prefixIcon: Icon(Icons.message),
            ),
            maxLines: 2,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter message' : null,
          ),
          const SizedBox(height: 16),
          Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
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
                  label: const Text('Send Test Message'),
                ),
              )),
        ],
      ),
    );
  }
}
