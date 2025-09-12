import 'package:flutter/material.dart';
import 'package:pos_machine/components/build_container_box.dart';
import 'package:pos_machine/resources/color_manager.dart';
import 'package:pos_machine/resources/font_manager.dart';
import 'package:pos_machine/resources/style_manager.dart';
import 'package:get/get.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../controllers/whatsapp_controller.dart';

class WhatsappSettingsScreen extends StatelessWidget {
  const WhatsappSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 1200;
    final ctrl = Get.put(WhatsappController(), permanent: true);

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
              Text(
                'WhatsApp Settings',
                style: buildCustomStyle(
                  FontWeightManager.semiBold,
                  FontSize.s20,
                  0.30,
                  ColorManager.textColor,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: GridView(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: isWide ? 520 : 440,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: isWide ? 1.2 : 1.4,
                      ),
                      children: [
                        // Connection Card
                        BuildBoxShadowContainer(
                          circleRadius: 12,
                          offsetValue: const Offset(1, 1),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Connection',
                                      style: buildCustomStyle(
                                        FontWeightManager.medium,
                                        FontSize.s16,
                                        0.24,
                                        ColorManager.textColor,
                                      ),
                                    ),
                                    Obx(() => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: ctrl.connected.value
                                                ? const Color(0xFF25D366).withOpacity(0.12)
                                                : Colors.orange.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(
                                              color: ctrl.connected.value ? const Color(0xFF25D366) : Colors.orange,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            ctrl.connected.value ? 'Connected' : 'Not Connected',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.18,
                                              ctrl.connected.value ? const Color(0xFF128C7E) : Colors.orange,
                                            ),
                                          ),
                                        )),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Scan the QR code from WhatsApp on your phone (Linked Devices) to connect. First desktop launch may take time to download Chromium.',
                                  style: buildCustomStyle(
                                    FontWeightManager.regular,
                                    FontSize.s12,
                                    0.18,
                                    ColorManager.textColor,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Obx(() {
                                  final qr = ctrl.qrCode.value;
                                  final isConnecting = ctrl.isConnecting.value;
                                  final connected = ctrl.connected.value;
                                  
                                  return AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    child: qr.isNotEmpty
                                        ? Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                color: Colors.white,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.grey.withOpacity(0.2),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: SizedBox(
                                                height: 140,
                                                width: 140,
                                                child: PrettyQrView.data(
                                                  data: qr,
                                                  decoration: const PrettyQrDecoration(
                                                    shape: PrettyQrSmoothSymbol(
                                                      color: Color(0xFF25D366),
                                                    ),
                                                  ),
                                                  errorCorrectLevel: QrErrorCorrectLevel.M,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Center(
                                            child: Container(
                                              height: 160,
                                              width: 160,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                color: Colors.grey.shade100,
                                                border: Border.all(
                                                  color: isConnecting 
                                                      ? const Color(0xFF25D366).withOpacity(0.3)
                                                      : Colors.grey.shade300,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  if (isConnecting) ...[
                                                    const CircularProgressIndicator(
                                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Text(
                                                      connected 
                                                          ? 'Connected!'
                                                          : ctrl.progress.value < 20
                                                              ? 'Initializing...'
                                                              : 'Generating QR...',
                                                      style: buildCustomStyle(
                                                        FontWeightManager.medium,
                                                        FontSize.s12,
                                                        0.18,
                                                        const Color(0xFF25D366),
                                                      ),
                                                    ),
                                                  ] else ...[
                                                    Icon(
                                                      Icons.qr_code_2,
                                                      size: 48,
                                                      color: Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      connected 
                                                          ? 'Connected!'
                                                          : 'QR will appear here',
                                                      style: buildCustomStyle(
                                                        FontWeightManager.medium,
                                                        FontSize.s12,
                                                        0.18,
                                                        connected ? const Color(0xFF25D366) : Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                  );
                                }),
                                const SizedBox(height: 12),
                                Obx(() => Row(
                                      children: [
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: ctrl.progress.value == 0 ? null : ctrl.progress.value / 100.0,
                                            minHeight: 6,
                                            backgroundColor: Colors.grey.shade200,
                                            color: const Color(0xFF25D366),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text('${ctrl.progress.value}%'),
                                      ],
                                    )),
                                const SizedBox(height: 12),
                                Obx(() => Wrap(
                                      spacing: 10,
                                      runSpacing: 8,
                                      children: [
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF25D366),
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: ctrl.isConnecting.value || ctrl.connected.value
                                              ? null
                                              : () {
                                                  ctrl.connect();
                                                },
                                          child: ctrl.isConnecting.value
                                              ? const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                                )
                                              : const Text('Connect'),
                                        ),
                                        OutlinedButton(
                                          onPressed: () {
                                            ctrl.reset();
                                          },
                                          child: const Text('Reset'),
                                        ),
                                        if (ctrl.error.value.contains('Failed to unzip') || 
                                            ctrl.error.value.contains('chrome binaries'))
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: ctrl.isConnecting.value
                                                ? null
                                                : () {
                                                    ctrl.clearCacheAndReconnect();
                                                  },
                                            child: const Text('Clear Cache & Retry'),
                                          ),
                                      ],
                                    )),
                                const SizedBox(height: 8),
                                Obx(() => ctrl.error.value.isEmpty
                                    ? const SizedBox.shrink()
                                    : Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.shade200),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ctrl.error.value,
                                              style: buildCustomStyle(
                                                FontWeightManager.medium,
                                                FontSize.s12,
                                                0.18,
                                                Colors.red.shade700,
                                              ),
                                            ),
                                            if (ctrl.error.value.contains('Failed to unzip') || 
                                                ctrl.error.value.contains('chrome binaries')) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                'Troubleshooting:\n• Try "Clear Cache & Retry" button\n• Run app as Administrator\n• Temporarily disable antivirus\n• Check available disk space',
                                                style: buildCustomStyle(
                                                  FontWeightManager.regular,
                                                  FontSize.s11,
                                                  0.16,
                                                  Colors.red.shade600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Send Test Message Card
                        BuildBoxShadowContainer(
                          circleRadius: 12,
                          offsetValue: const Offset(1, 1),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Send Test Message',
                                  style: buildCustomStyle(
                                    FontWeightManager.medium,
                                    FontSize.s16,
                                    0.24,
                                    ColorManager.textColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _PhoneAndMessageForm(ctrl: ctrl),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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
            decoration: const InputDecoration(labelText: 'Phone (with country code) eg. +91xxxxxxxxxx'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter phone' : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _msg,
            decoration: const InputDecoration(labelText: 'Message'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter message' : null,
          ),
          const SizedBox(height: 12),
          Obx(() => ElevatedButton.icon(
                onPressed: widget.ctrl.connected.value
                    ? () {
                        if (_formKey.currentState?.validate() ?? false) {
                          widget.ctrl.sendTestMessage(_phone.text.trim(), _msg.text.trim());
                        }
                      }
                    : null,
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              )),
        ],
      ),
    );
  }
}
