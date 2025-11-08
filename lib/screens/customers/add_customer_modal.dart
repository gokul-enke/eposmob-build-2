import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';

import '../../newcomponents/custom_customer_form.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

Future<dynamic> showAddCustomerModal(BuildContext context, Size size,
    {required String mobileNumber}) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.transparent,
        child: Container(
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
              mobileNumber: mobileNumber), // Pass mobile number
        ),
      );
    },
  );
}

class AddCustomersModal extends StatefulWidget {
  final String mobileNumber;

  const AddCustomersModal({Key? key, required this.mobileNumber})
      : super(key: key);

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
                  'Add New Customer',
                  style: buildCustomStyle(FontWeightManager.semiBold,
                      FontSize.s20, 0.30, ColorManager.textColor),
                ),
              ],
            ),
          ),
          // Use the unified form
          CustomCustomerForm(
            initialMobileNumber: widget.mobileNumber,
            isModal: true,
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

