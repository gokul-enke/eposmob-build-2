import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/models/forgot_model_error.dart';

import 'package:pos_machine/providers/authentication_providers.dart';
import 'package:pos_machine/screens/login/reset_password.dart';

import '../../components/build_round_button.dart';
import '../../components/build_title.dart';

import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  bool isLoading = false;
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double height = size.height;
    double width = size.width;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
        ),
      ),
      body: Container(
        alignment: Alignment.center,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    height: height * .1,
                  ),
                  BuildTextTile(
                    title: 'login.forgot_title'.tr,
                    textStyle: buildTitleStyle,
                  ),
                  SizedBox(
                    height: height * .08,
                  ),
                  Form(
                    key: _formKey,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: size.width / 2,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 25),
                              child: TextFormField(
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: validateEmail,
                                key: const Key("Phone_Number_Sign_in"),
                                cursorColor: ColorManager.kPrimaryColor,
                                controller: _emailController,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.allow(
                                      RegExp("[0-9@a-zA-Z.]")),
                                ],
                                keyboardType: TextInputType.emailAddress,
                                decoration: decoration.copyWith(
                                  prefixIcon: Icon(
                                    Icons.email_rounded,
                                    color: ColorManager.kPrimaryColor
                                        .withOpacity(0.5),
                                  ),
                                  hintText: 'login.hint_email'.tr,
                                  hintStyle: buildTextFieldStyle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),

                          // isLoading
                          //     ? const Center(
                          //         child: CircularProgressIndicator(
                          //           color: ColorManager.kPrimaryColor,
                          //         ),
                          //       )
                          //     :
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 25, vertical: 15),
                            child: CustomRoundButton(
                              width: width / 2.1,
                              fontSize: FontSize.s12,
                              height: size.height * .07,
                              key: const Key("Button_Sign_in"),
                              title: 'login.btn_continue'.tr,
                              fct: () async {
                                if (_emailController.text.isNotEmpty &&
                                    _formKey.currentState!.validate()) {
                                  // debugPrint("hello");
                                  showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) {
                                        return const Center(
                                          child: CircularProgressIndicator
                                              .adaptive(),
                                        );
                                      });
                                  await AuthenticationProvider()
                                      .forgotPassword(
                                          _emailController.text, context)
                                      .then((value) async {
                                    // Navigator.pop(context);
                                    if (value["status"] == "success") {
                                      // debugPrint(value.toString());

                                      showScaffold(
                                        context: context,
                                        message: '${value["message"]}',
                                      );
                                      Navigator.pop(context);
                                      await Future.delayed(
                                              const Duration(seconds: 0))
                                          .then((value) => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const ResetPasswordScreen())));
                                    } else {
                                      ForgotModelError forgotModelError =
                                          ForgotModelError.fromJson(value);

                                      Errors? errors = forgotModelError.errors;
                                      // debugPrint(errors!.email!.single);
                                      Navigator.pop(context);

                                      showScaffold(
                                        context: context,
                                        message: errors!.email!.single,
                                      );
                                    }
                                  });
                                } else {
                                  showScaffold(
                                    context: context,
                                    message: 'login.forgot_fill_required'.tr,
                                  );
                                }
                              },
                            ),
                          ),
//--------------------------------

                          // Padding(
                          //   padding: const EdgeInsets.symmetric(
                          //       horizontal: 25, vertical: 5),
                          //   child: CustomRoundButton(
                          //     width: width / 2,
                          //     fontSize: FontSize.s12,
                          //     height: size.height * .07,
                          //     key: const Key("Button_Sign_in"),
                          //     title: 'reset',
                          //     fct: () async {
                          //       Navigator.push(
                          //           context,
                          //           MaterialPageRoute(
                          //               builder: (context) =>
                          //                   const ResetPasswordScreen()));
                          //     },
                          //   ),
                          // ),
                        ]),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  String? validateEmail(String? value) {
    const pattern = r"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'"
        r'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-'
        r'\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*'
        r'[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4]'
        r'[0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9]'
        r'[0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\'
        r'x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])';
    final regex = RegExp(pattern);

    return value!.isNotEmpty && !regex.hasMatch(value)
        ? 'login.validator_email_invalid'.tr
        : null;
  }
}
