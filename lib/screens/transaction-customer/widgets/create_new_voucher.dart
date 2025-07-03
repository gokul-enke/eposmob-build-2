import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:pos_machine/components/build_back_button.dart';
import 'package:pos_machine/components/build_text_fields.dart';
import 'package:provider/provider.dart';

import '../../../components/build_container_box.dart';
import '../../../components/build_dialog_box.dart';
import '../../../components/build_round_button.dart';

import '../../../components/build_title.dart';
import '../../../controllers/sidebar_controller.dart';

import '../../../models/get_users.dart';
import '../../../providers/auth_model.dart';
import '../../../providers/invoice_provider.dart';
import '../../../resources/color_manager.dart';
import '../../../resources/font_manager.dart';
import '../../../resources/style_manager.dart';

class CreateNewVoucherScreen extends StatefulWidget {
  const CreateNewVoucherScreen({Key? key}) : super(key: key);

  @override
  _CreateNewVoucherScreenState createState() => _CreateNewVoucherScreenState();
}

class _CreateNewVoucherScreenState extends State<CreateNewVoucherScreen> {
  final TextEditingController paymentMethodRefController =
      TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  final TextEditingController particularsController = TextEditingController();
  final TextEditingController toIdController = TextEditingController();

  String? paymentSelected;
  String? voucherSelected;
  GetUsersModelData? selectedUser;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    InvoiceProvider invoiceProvider = Provider.of<InvoiceProvider>(context);
    Map<String, String>? paymentList = invoiceProvider.getPaymentType;
    Map<String, String>? getVoucherAccountTypesModelData =
        invoiceProvider.getVoucherAccountTypes;
    List<GetUsersModelData>? getUsersList = invoiceProvider.getUsersList;
    SideBarController sideBarController = Get.put(SideBarController());

    return SafeArea(
      child: Container(
          margin:
              const EdgeInsets.only(left: 10, top: 20, bottom: 0, right: 10),
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
            padding: const EdgeInsets.only(top: 20.0, left: 10, right: 10),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBackButton(
                    onPressed: () {
                      sideBarController.index.value = 22;
                    },
                    text: 'Voucher List',
                  ),
                  Text(
                    'Create New Voucher',
                    style: buildCustomStyle(FontWeightManager.semiBold,
                        FontSize.s20, 0.30, ColorManager.textColor),
                  ),
                  const SizedBox(height: 20),
                  BuildBoxShadowContainer(
                    circleRadius: 7,
                    blurRadius: 6,
                    padding: const EdgeInsets.only(
                        left: 10.0, right: 20, top: 30, bottom: 10),
                    offsetValue: const Offset(1, 1),
                    child: Form(
                        key: formKey,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      BuildTextTile(
                                        isStarRed: true,
                                        isTextField: true,
                                        title: 'Account type',
                                        textStyle: buildCustomStyle(
                                          FontWeightManager.regular,
                                          FontSize.s14,
                                          0.27,
                                          Colors.black.withOpacity(0.6),
                                        ),
                                      ),
                                      BuildBoxShadowContainer(
                                        circleRadius: 7,
                                        alignment: Alignment.centerLeft,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 0),
                                        padding:
                                            const EdgeInsets.only(left: 15),
                                        height: size.height * .07,
                                        width: size.width / 3,
                                        child: DropdownButtonFormField<String>(
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                          ),
                                          value: voucherSelected,
                                          hint: Text(
                                            'Select An Account type',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.27,
                                              ColorManager.textColor
                                                  .withOpacity(.5),
                                            ),
                                          ),
                                          items: getVoucherAccountTypesModelData
                                              ?.entries
                                              .map((MapEntry<String, String>
                                                  entry) {
                                            return DropdownMenuItem(
                                              value: entry.key,
                                              child: Text(
                                                entry.value,
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? value) {
                                            setState(() {
                                              voucherSelected = value;
                                            });
                                          },
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'This field is required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      BuildTextTile(
                                        isStarRed: true,
                                        isTextField: true,
                                        title: "Payment Method",
                                        textStyle: buildCustomStyle(
                                          FontWeightManager.regular,
                                          FontSize.s14,
                                          0.27,
                                          Colors.black.withOpacity(0.6),
                                        ),
                                      ),
                                      BuildBoxShadowContainer(
                                        circleRadius: 7,
                                        alignment: Alignment.centerLeft,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 0),
                                        padding:
                                            const EdgeInsets.only(left: 15),
                                        height: size.height * .07,
                                        width: size.width / 3,
                                        child: DropdownButtonFormField<String>(
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                          ),
                                          value: paymentSelected,
                                          hint: Text(
                                            'Select A Payment Method',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.27,
                                              ColorManager.textColor
                                                  .withOpacity(.5),
                                            ),
                                          ),
                                          items:
                                              paymentList!.entries.map((entry) {
                                            return DropdownMenuItem<String>(
                                              value: entry.key,
                                              child: Text(
                                                entry.value,
                                                style: buildCustomStyle(
                                                  FontWeightManager.medium,
                                                  FontSize.s12,
                                                  0.27,
                                                  ColorManager.textColor
                                                      .withOpacity(.5),
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (String? value) {
                                            setState(() {
                                              paymentSelected = value;
                                            });
                                          },
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'This field is required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  BuildTextFieldColumn(
                                    isLeft: false,
                                    size: size,
                                    isStarRed: true,
                                    hintText: 'Ref',
                                    isTextField: true,
                                    read: false,
                                    controller: paymentMethodRefController,
                                    title: "Payment Method Ref",
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'This field is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  BuildTextFieldColumn(
                                    isLeft: true,
                                    isStarRed: true,
                                    isTextField: true,
                                    size: size,
                                    hintText: 'Amount',
                                    read: false,
                                    textInputType:
                                        const TextInputType.numberWithOptions(),
                                    controller: amountController,
                                    title: "Amount",
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'This field is required';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      BuildTextTile(
                                        isStarRed: true,
                                        isTextField: true,
                                        title: "To",
                                        textStyle: buildCustomStyle(
                                          FontWeightManager.regular,
                                          FontSize.s14,
                                          0.27,
                                          Colors.black.withOpacity(0.6),
                                        ),
                                      ),
                                      BuildBoxShadowContainer(
                                        circleRadius: 7,
                                        alignment: Alignment.centerLeft,
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 0),
                                        padding:
                                            const EdgeInsets.only(left: 15),
                                        height: size.height * .07,
                                        width: size.width / 2.9,
                                        child: DropdownButtonFormField<
                                            GetUsersModelData>(
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                          ),
                                          value: selectedUser,
                                          hint: Text(
                                            'Select a User',
                                            style: buildCustomStyle(
                                              FontWeightManager.medium,
                                              FontSize.s12,
                                              0.27,
                                              ColorManager.textColor
                                                  .withOpacity(.5),
                                            ),
                                          ),
                                          items: getUsersList!
                                              .map((GetUsersModelData user) {
                                                return DropdownMenuItem<
                                                    GetUsersModelData>(
                                                  value: user,
                                                  child: Text(
                                                    user.name ?? '',
                                                    style: buildCustomStyle(
                                                      FontWeightManager.medium,
                                                      FontSize.s12,
                                                      0.27,
                                                      ColorManager.textColor
                                                          .withOpacity(.5),
                                                    ),
                                                  ),
                                                );
                                              })
                                              .toSet()
                                              .toList(),
                                          onChanged:
                                              (GetUsersModelData? selectUser) {
                                            if (selectUser != null) {
                                              setState(() {
                                                selectedUser = selectUser;
                                                toIdController.text =
                                                    "${selectUser.id}";
                                              });
                                            }
                                          },
                                          validator: (value) {
                                            if (value == null) {
                                              return 'This field is required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  BuildTextFieldColumn(
                                    isLeft: true,
                                    size: size,
                                    isStarRed: false,
                                    hintText: 'Comment',
                                    isTextField: true,
                                    maxlines: 3,
                                    read: false,
                                    controller: commentController,
                                    title: "Comment",
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  BuildTextFieldColumn(
                                    isLeft: false,
                                    isStarRed: false,
                                    isTextField: true,
                                    size: size,
                                    read: false,
                                    hintText: 'Particulars',
                                    controller: particularsController,
                                    title: "Particulars",
                                  ),
                                ],
                              ),
                              const SizedBox(height: 45),
                              Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 10.0),
                                    child: CustomRoundButton(
                                      title: "Submit",
                                      fct: () async {
                                        if (formKey.currentState!.validate()) {
                                          formKey.currentState!.save();
                                          debugPrint(
                                              " selectedUser $selectedUser  ${toIdController.text}\t voucherSelected $voucherSelected\npaymentSelected  $paymentSelected");
                                          // if (toIdController.text.isEmpty ||
                                          //     paymentSelected == null ||
                                          //     voucherSelected == null ||
                                          //     paymentMethodRefController
                                          //         .text.isEmpty ||
                                          //     amountController.text.isEmpty) {
                                          //   showScaffold(
                                          //     context: context,
                                          //     message:
                                          //         'Please Fill the Required Fields',
                                          //   );
                                          // } else {
                                          showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) {
                                                return const Center(
                                                  child:
                                                      CircularProgressIndicator
                                                          .adaptive(),
                                                );
                                              });

                                          String? accessToken =
                                              Provider.of<AuthModel>(context,
                                                      listen: false)
                                                  .token;
                                          debugPrint(
                                              "accessToken From AuthModel $accessToken");
                                          invoiceProvider
                                              .addVoucher(
                                                  comment:
                                                      commentController.text,
                                                  particular:
                                                      particularsController
                                                          .text,
                                                  accountType:
                                                      voucherSelected ?? "",
                                                  paymentMethod:
                                                      paymentSelected ?? '',
                                                  paymentMethodRef:
                                                      paymentMethodRefController
                                                          .text,
                                                  amount: amountController.text,
                                                  toUserID: toIdController.text,
                                                  type: "voucher",
                                                  accessToken:
                                                      accessToken ?? "")
                                              .then((value) {
                                            if (value["status"] == "success") {
                                              showScaffold(
                                                  context: context,
                                                  message: value["message"]);

                                              Navigator.pop(context);
                                              sideBarController.index.value =
                                                  22;
                                            } else {
                                              Navigator.pop(context);

                                              showScaffold(
                                                  context: context,
                                                  message: value["message"]);
                                              sideBarController.index.value =
                                                  22;
                                            }
                                          });
                                          // }
                                        } else {
                                          showScaffold(
                                            context: context,
                                            message:
                                                'Please fill all required fields',
                                          );
                                        }
                                      },
                                      height: 50,
                                      width: size.width * 0.19,
                                      fontSize: FontSize.s12,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 10.0),
                                    child: CustomRoundButton(
                                      title: "Back",
                                      boxColor: Colors.white,
                                      textColor: ColorManager.kPrimaryColor,
                                      fct: () async {
                                        sideBarController.index.value = 22;
                                      },
                                      height: 50,
                                      width: size.width * 0.19,
                                      fontSize: FontSize.s12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                height: 50,
                              )
                            ])),
                  ),
                ],
              ),
            ),
          )),
    );
  }
}
