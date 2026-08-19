import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

import '../../newcomponents/custom_customer_form.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

Future<dynamic> showAddCustomerModal(
  BuildContext context,
  Size size, {
  required String mobileNumber,
  String? customerName,
}) {
  // Clear any focused field behind the dialog to avoid multiple cursors.
  FocusManager.instance.primaryFocus?.unfocus();
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.of(context).pop();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width > 700 ? 600 : double.infinity,
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: AddCustomersModal(
              mobileNumber: mobileNumber,
              customerName: customerName,
            ),
          ),
        ),
      );
    },
  );
}

class AddCustomersModal extends StatefulWidget {
  final String mobileNumber;
  final String? customerName;

  const AddCustomersModal({
    Key? key,
    required this.mobileNumber,
    this.customerName,
  }) : super(key: key);

  @override
  State<AddCustomersModal> createState() => _AddCustomersModalState();
}

class _AddCustomersModalState extends State<AddCustomersModal> {
  @override
  Widget build(BuildContext context) {
    Get.put(SideBarController());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10.0, bottom: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'add_customer.title'.tr,
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
              ],
            ),
          ),
          // Use the unified form
          CustomCustomerForm(
            initialMobileNumber: widget.mobileNumber,
            initialCustomerName: widget.customerName,
            isModal: true,
            isMobileLayout: MediaQuery.of(context).size.width < 700,
            onSuccess: () {
              // Form handles success internally for modal
            },
            onCancel: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
