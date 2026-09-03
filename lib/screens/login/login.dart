import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/providers/authentication_providers.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/helpers/debug_login_autofill.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/services/session_reset_service.dart';
import 'package:pos_machine/screens/login/forgot_password.dart';
import 'package:pos_machine/screens/login/store_selection_screen.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/features/subscription/presentation/subscription_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/build_round_button.dart';
import '../../components/build_title.dart';
import '../../providers/auth_model.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import '../../helpers/date_helper.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    Key? key,
  }) : super(key: key);

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _obscureText = true;
  bool _rememberMe = false;

  final _emailController = TextEditingController();
  final _passwordTextController = TextEditingController();
  bool isLoading = false;
  // Add new state variables for data loading
  bool _isLoadingData = false;
  String _loadingMessage = 'login.loading_data'.tr;

  @override
  void initState() {
    super.initState();
    _loadUserEmailPassword();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDefaultDomainWarningIfAny();
    });
  }

  Future<void> _showDefaultDomainWarningIfAny() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shouldShow = prefs.getBool('show_default_domain_warning') ?? false;
      if (!shouldShow) {
        return;
      }

      await prefs.setBool('show_default_domain_warning', false);

      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'login.error_default_domain'.tr,
        );
      }
    } catch (_) {}
  }

  void _loadUserEmailPassword() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      var prefsEmail = prefs.getString("emailRemember") ?? "";
      var prefsPassword = prefs.getString("passwordRemember") ?? "";
      var prefsRememberMe = prefs.getBool("remember_me") ?? false;

      if (prefsRememberMe) {
        setState(() {
          _rememberMe = true;
        });
        _emailController.text = prefsEmail;
        _passwordTextController.text = prefsPassword;
      }

      await DebugLoginAutofill.applyLoginIfNeeded(
        emailController: _emailController,
        passwordController: _passwordTextController,
      );
      if (mounted) setState(() {});
    } catch (e) {
      rethrow;
    }
  }

  void _handleRememberMe(bool value) {
    _rememberMe = value;
    SharedPreferences.getInstance().then(
      (prefs) {
        prefs.setBool("remember_me", value);
        prefs.setString('emailRemember', _emailController.text);
        prefs.setString('passwordRemember', _passwordTextController.text);
      },
    );
    setState(() {
      _rememberMe = value;
    });
  }

  Future<void> _resetApiKey() async {
    try {
      await SessionResetService.resetForApiKeyReset(context);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/api-key');
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'login.error_reset_api_key'.tr,
        );
      }
    }
  }

  // Add method to update loading state and message
  void _updateLoadingState(bool isLoading, String message) {
    if (mounted) {
      setState(() {
        _isLoadingData = isLoading;
        _loadingMessage = message;
      });
    }
  }

  @override
  void dispose() {
    _emailController.clear();
    _passwordTextController.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    double height = size.height;
    double width = size.width;
    // Responsive helpers
    final bool isMobile = width < 600;
    final double formWidth = isMobile ? (width - 40) : (width / 2);
    final EdgeInsets fieldPadding =
        EdgeInsets.symmetric(horizontal: isMobile ? 16 : 25);
    final double titleTopSpace = isMobile ? height * .06 : height * .1;
    final double betweenTitleAndForm = isMobile ? 24.0 : height * .08;
    final authModel = Provider.of<AuthModel>(context);
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Container(
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
                          height: titleTopSpace,
                        ),
                        BuildTextTile(
                          title: 'login.title'.tr,
                          textStyle: buildTitleStyle,
                        ),
                        SizedBox(
                          height: betweenTitleAndForm,
                        ),
                        Form(
                          key: _formKey,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: formWidth,
                                  child: Padding(
                                    padding: fieldPadding,
                                    child: TextFormField(
                                      autovalidateMode:
                                          AutovalidateMode.onUserInteraction,
                                      validator: validateEmail,
                                      key: const Key("Phone_Number_Sign_in"),
                                      cursorColor: ColorManager.kPrimaryColor,
                                      controller: _emailController,
                                      showCursor: true,
                                      onTap: () {
                                        Provider.of<KeyboardProvider>(context,
                                                listen: false)
                                            .show('email', _emailController);
                                      },
                                      inputFormatters: <TextInputFormatter>[
                                        FilteringTextInputFormatter.allow(RegExp(
                                            r"[0-9@a-zA-Z.!#$%&'*+/=?^_`{|}~-]")),
                                      ],
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: decoration.copyWith(
                                        prefixIcon: Icon(
                                          Icons.email_rounded,
                                          color: ColorManager.kPrimaryColor
                                              .withOpacity(0.5),
                                        ),
                                        hintText: '*****@domain.com',
                                        hintStyle: buildTextFieldStyle,
                                        errorBorder: const OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2.0,
                                          ),
                                        ),
                                        focusedErrorBorder:
                                            const OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 30,
                                ),
                                SizedBox(
                                  width: formWidth,
                                  child: Padding(
                                    padding: fieldPadding,
                                    child: TextFormField(
                                      key: const Key("Password_Sign_in"),
                                      obscureText: _obscureText,
                                      cursorColor: ColorManager.kPrimaryColor,
                                      controller: _passwordTextController,
                                      showCursor: true,
                                      onTap: () {
                                        Provider.of<KeyboardProvider>(context,
                                                listen: false)
                                            .show('password',
                                                _passwordTextController);
                                      },
                                      // validator:
                                      //     validatePassword, // Add validator here
                                      decoration: decoration.copyWith(
                                        hintText: '*******',
                                        iconColor:
                                            ColorManager.kPrimaryWithOpacity10,
                                        prefixIcon: Icon(
                                          Icons.lock_clock_rounded,
                                          color: ColorManager.kPrimaryColor
                                              .withOpacity(0.5),
                                        ),
                                        hintStyle: buildTextFieldStyle,
                                        suffixIcon: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _obscureText = !_obscureText;
                                            });
                                          },
                                          child: Icon(
                                            _obscureText
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: ColorManager.kPrimaryColor
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                        errorBorder: const OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2.0,
                                          ),
                                        ),
                                        focusedErrorBorder:
                                            const OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: formWidth,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.all(isMobile ? 16.0 : 30.0),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        InkWell(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          onTap: () {
                                            setState(() {
                                              _rememberMe = !_rememberMe;
                                              _handleRememberMe(_rememberMe);
                                            });
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                height: isMobile ? 24 : 20,
                                                width: isMobile ? 24 : 20,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: _rememberMe
                                                      ? null
                                                      : Border.all(
                                                          color:
                                                              ColorManager.grey,
                                                          width: 2.0,
                                                        ),
                                                  color: _rememberMe
                                                      ? ColorManager
                                                          .kPrimaryColor
                                                      : Colors.white,
                                                ),
                                                alignment: Alignment.center,
                                                child: _rememberMe
                                                    ? const Icon(
                                                        Icons.check,
                                                        size: 14,
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                              SizedBox(
                                                  width: isMobile ? 12 : 10),
                                              Text(
                                                'login.remember_me'.tr,
                                                style: const TextStyle(
                                                  fontWeight:
                                                      FontWeightManager.regular,
                                                  fontFamily:
                                                      FontConstants.fontFamily,
                                                  fontSize: FontSize.s10,
                                                  letterSpacing: 0.2,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (context) =>
                                                        const ForgotPasswordScreen()));
                                          },
                                          child: Text(
                                            'login.forgot_password'.tr,
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeightManager.medium,
                                              fontFamily:
                                                  FontConstants.fontFamily,
                                              fontSize: FontSize.s10,
                                              letterSpacing: 0.16,
                                              color: ColorManager.kPrimaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          color: ColorManager.kPrimaryColor,
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 25, vertical: 5),
                                        child: CustomRoundButton(
                                          width: formWidth,
                                          fontSize: FontSize.s12,
                                          height: size.height * .07,
                                          key: const Key("Button_Sign_in"),
                                          title: 'login.btn_continue'.tr,
                                          fct: () async {
                                            if (_formKey.currentState!
                                                .validate()) {
                                              // Show our new loading overlay instead of the dialog
                                              _updateLoadingState(
                                                  true,
                                                  'login.loading_logging_in'
                                                      .tr);

                                              // Save remember me state when login button is pressed
                                              _handleRememberMe(_rememberMe);

                                              try {
                                                final value =
                                                    await AuthenticationProvider().login(
                                                        _emailController.text
                                                            .trim(),
                                                        _passwordTextController
                                                            .text,
                                                        context);
                                                if (value["status"] ==
                                                    "success") {
                                                  ExecutiveModel
                                                      executiveModel =
                                                      ExecutiveModel.fromJson(
                                                          value);
                                                  ExecutiveModelData?
                                                      executiveModelData =
                                                      executiveModel.data;

                                                  authModel.login(
                                                      executiveModelData
                                                              ?.accessToken ??
                                                          "",
                                                      executiveModelData
                                                              ?.userId ??
                                                          0);

                                                  // Convert stores list to JSON string
                                                  String? storesJson;
                                                  if (executiveModelData
                                                          ?.stores !=
                                                      null) {
                                                    storesJson = json.encode(
                                                        executiveModelData!
                                                            .stores!
                                                            .map((store) =>
                                                                store.toJson())
                                                            .toList());
                                                  }

                                                  final String? countryName =
                                                      value['data']?['country']
                                                              ?['name']
                                                          ?.toString();

                                                  await SharedPreferenceProvider()
                                                      .saveAccessTokenandCustomerId(
                                                    executiveModelData
                                                            ?.accessToken ??
                                                        "",
                                                    executiveModelData
                                                            ?.userId ??
                                                        0,
                                                    executiveModelData
                                                            ?.userName ??
                                                        "",
                                                    executiveModelData
                                                            ?.userRole ??
                                                        "",
                                                    tokenType:
                                                        executiveModelData
                                                            ?.tokenType,
                                                    companyId:
                                                        executiveModelData
                                                            ?.companyId,
                                                    companyName:
                                                        executiveModelData
                                                            ?.companyName,
                                                    storesJson: storesJson,
                                                    timeZone: executiveModelData
                                                        ?.timeZone,
                                                    countryName: countryName,
                                                  );

                                                  final subscriptionProvider =
                                                      context.read<
                                                          SubscriptionProvider>();
                                                  final subscriptionInLogin =
                                                      await subscriptionProvider
                                                          .applyLoginPayload(
                                                              value);
                                                  if (!subscriptionInLogin) {
                                                    await subscriptionProvider
                                                        .refresh();
                                                  }

                                                  // Update DateHelper with the new timezone
                                                  if (executiveModelData
                                                          ?.timeZone !=
                                                      null) {
                                                    DateHelper.setTimeZone(
                                                        executiveModelData!
                                                            .timeZone!);
                                                  }

                                                  // Save ZATCA credentials for Saudi Arabia e-invoicing
                                                  if (executiveModelData
                                                              ?.crNumber !=
                                                          null ||
                                                      executiveModelData
                                                              ?.vatNumber !=
                                                          null ||
                                                      executiveModelData
                                                              ?.zatcaCompanyName !=
                                                          null) {
                                                    SharedPreferenceProvider()
                                                        .saveZatcaCredentials(
                                                      crNumber:
                                                          executiveModelData
                                                              ?.crNumber,
                                                      vatNumber:
                                                          executiveModelData
                                                              ?.vatNumber,
                                                      companyName:
                                                          executiveModelData
                                                              ?.zatcaCompanyName,
                                                    );
                                                    debugPrint(
                                                        "ZATCA credentials saved - CR: ${executiveModelData?.crNumber}, VAT: ${executiveModelData?.vatNumber}, Company: ${executiveModelData?.zatcaCompanyName}");
                                                  }

                                                  SalesProvider salesProvider =
                                                      Provider.of<
                                                              SalesProvider>(
                                                          context,
                                                          listen: false);
                                                  salesProvider.setUserId(
                                                    executiveModelData
                                                            ?.userId ??
                                                        0,
                                                  );
                                                  showScaffold(
                                                    context: context,
                                                    message:
                                                        '${value["message"]}',
                                                  );

                                                  _updateLoadingState(
                                                      false, "");

                                                  // Set appropriate home page based on user role
                                                  final sideBarController =
                                                      Get.find<
                                                          SideBarController>();
                                                  String userRole =
                                                      executiveModelData
                                                              ?.userRole ??
                                                          "";

                                                  switch (userRole) {
                                                    case 'attender':
                                                      sideBarController
                                                              .index.value =
                                                          55; // Restaurant Page
                                                      break;
                                                    case 'kitchen_master':
                                                      sideBarController
                                                              .index.value =
                                                          56; // Kitchen Master Page
                                                      break;
                                                    case 'company_admin':
                                                      sideBarController
                                                              .index.value =
                                                          1; // Dashboard
                                                      break;
                                                    case 'restaurant_sales':
                                                      sideBarController
                                                              .index.value =
                                                          89; // Restaurant Billing Page
                                                      break;
                                                    case 'sales_executive':
                                                    default:
                                                      sideBarController
                                                              .index.value =
                                                          90; // Billing Page
                                                      break;
                                                  }

                                                  await Future.delayed(
                                                      const Duration(
                                                          seconds: 1));

                                                  if (executiveModelData
                                                              ?.stores !=
                                                          null &&
                                                      executiveModelData!
                                                          .stores!.isNotEmpty) {
                                                    // Navigate to store selection screen
                                                    Navigator.pushReplacement(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            StoreSelectionScreen(
                                                          stores:
                                                              executiveModelData
                                                                  .stores!,
                                                          isFromLogin: true,
                                                        ),
                                                      ),
                                                    );
                                                  } else {
                                                    _updateLoadingState(
                                                        false, "");
                                                    showScaffoldError(
                                                      context: context,
                                                      message:
                                                          'login.error_no_store_permission'
                                                              .tr,
                                                    );
                                                  }
                                                } else {
                                                  _updateLoadingState(
                                                      false, "");
                                                  showScaffoldError(
                                                    context: context,
                                                    message:
                                                        '${value["message"]}',
                                                  );
                                                }
                                              } on ApiKeyRequiredException {
                                                _updateLoadingState(false, "");
                                                if (mounted) {
                                                  Navigator
                                                      .pushReplacementNamed(
                                                          context, '/api-key');
                                                }
                                              } catch (e) {
                                                _updateLoadingState(false, "");
                                                showScaffoldError(
                                                  context: context,
                                                  message: e.toString(),
                                                );
                                              }
                                            } else {
                                              showScaffoldError(
                                                  context: context,
                                                  message:
                                                      'login.error_fill_details'
                                                          .tr);
                                            }
                                          },
                                        ),
                                      ),
                                // Reset API Key Button
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: formWidth,
                                  child: Padding(
                                    padding: fieldPadding,
                                    child: TextButton.icon(
                                      onPressed: _resetApiKey,
                                      icon: const Icon(
                                        Icons.refresh,
                                        size: 16,
                                        color: ColorManager.kPrimaryColor,
                                      ),
                                      label: Text(
                                        'login.btn_reset_api_key'.tr,
                                        style: const TextStyle(
                                          fontWeight: FontWeightManager.medium,
                                          fontFamily: FontConstants.fontFamily,
                                          fontSize: FontSize.s10,
                                          letterSpacing: 0.16,
                                          color: ColorManager.kPrimaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                        ),
                      ]),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: Icon(
                    Provider.of<KeyboardProvider>(context).showKeyboardFeature
                        ? Icons.keyboard_hide
                        : Icons.keyboard,
                    color: Provider.of<KeyboardProvider>(context)
                            .showKeyboardFeature
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade600,
                  ),
                  tooltip:
                      Provider.of<KeyboardProvider>(context).showKeyboardFeature
                          ? 'login.tooltip_hide_keyboard'.tr
                          : 'login.tooltip_show_keyboard'.tr,
                  onPressed: () {
                    final keyboardProvider =
                        Provider.of<KeyboardProvider>(context, listen: false);
                    if (keyboardProvider.showKeyboardFeature) {
                      keyboardProvider.featureOff();
                      keyboardProvider.clear();
                    } else {
                      keyboardProvider.featureOn();
                    }
                  },
                ),
              ),
            ),
          ),

          // Add overlay for data loading
          if (_isLoadingData)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool validateAndSave() {
    final form = _formKey.currentState;
    if (form!.validate()) {
      form.save();
      return true;
    }
    return false;
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

    if (value == null || value.isEmpty) {
      return 'login.validator_email_required'.tr;
    }

    if (!regex.hasMatch(value)) {
      return 'login.validator_email_invalid'.tr;
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'login.validator_password_required'.tr;
    }
    RegExp regex =
        RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
    if (!regex.hasMatch(value)) {
      return 'login.validator_password_invalid'.tr;
    }
    return null;
  }
}
