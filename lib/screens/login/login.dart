// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:pos_machine/components/build_dialog_box.dart';
// import 'package:pos_machine/components/main_screen.dart';
// import 'package:pos_machine/models/executive.dart';
// import 'package:pos_machine/providers/authentication_providers.dart';
// import 'package:pos_machine/providers/keyboard_provider.dart';
// import 'package:pos_machine/providers/local_product_provider.dart';
// import 'package:pos_machine/providers/sales_provider.dart';
// import 'package:pos_machine/providers/shared_preferences.dart';
// import 'package:pos_machine/providers/document_config_provider.dart';
// import 'package:pos_machine/providers/category_providers.dart';
// import 'package:pos_machine/screens/login/forgot_password.dart';
// import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import '../../components/build_round_button.dart';
// import '../../components/build_title.dart';
// import '../../providers/auth_model.dart';
// import '../../providers/invoice_provider.dart';
// import '../../providers/purchase_provider.dart';
// import '../../resources/color_manager.dart';
// import '../../resources/font_manager.dart';
// import '../../resources/style_manager.dart';

// class SignInScreen extends StatefulWidget {
//   const SignInScreen({
//     Key? key,
//   }) : super(key: key);

//   @override
//   State<SignInScreen> createState() => _SignInScreenState();
// }

// class _SignInScreenState extends State<SignInScreen> {
//   final _formKey = GlobalKey<FormState>();
//   bool _obscureText = true;
//   bool _rememberMe = false;
//   final _emailController = TextEditingController();
//   final _passwordTextController = TextEditingController();
//   bool isLoading = false;

//   @override
//   void initState() {
//     super.initState();
//     _loadUserEmailPassword();
//   }

//   void _loadUserEmailPassword() async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       var prefsEmail = prefs.getString("emailRemember") ?? "";
//       var prefsPassword = prefs.getString("passwordRemember") ?? "";
//       var prefsRememberMe = prefs.getBool("remember_me") ?? false;

//       if (prefsRememberMe) {
//         setState(() {
//           _rememberMe = true;
//         });
//         _emailController.text = prefsEmail;
//         _passwordTextController.text = prefsPassword;
//       }
//     } catch (e) {
//       rethrow;
//     }
//   }

//   void _handleRememberMe(bool value) {
//     _rememberMe = value;
//     SharedPreferences.getInstance().then(
//       (prefs) {
//         prefs.setBool("remember_me", value);
//         prefs.setString('emailRemember', _emailController.text);
//         prefs.setString('passwordRemember', _passwordTextController.text);
//       },
//     );
//     setState(() {
//       _rememberMe = value;
//     });
//   }

//   Future<void> _resetApiKey() async {
//     try {
//       SharedPreferences prefs = await SharedPreferences.getInstance();
//       await prefs.remove('api_key');
      
//       if (mounted) {
//         Navigator.pushReplacementNamed(context, '/api-key');
//       }
//     } catch (e) {
//       if (mounted) {
//         showScaffoldError(
//           context: context,
//           message: 'Failed to reset API key. Please try again.',
//         );
//       }
//     }
//   }

//   @override
//   void dispose() {
//     _emailController.clear();
//     _passwordTextController.clear();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     Size size = MediaQuery.of(context).size;
//     double height = size.height;
//     double width = size.width;
//     final authModel = Provider.of<AuthModel>(context);
//     return Scaffold(
//       body: Container(
//         alignment: Alignment.center,
//         child: SingleChildScrollView(
//           physics: const AlwaysScrollableScrollPhysics(),
//           child: Padding(
//             padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
//             child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   SizedBox(
//                     height: height * .1,
//                   ),
//                   BuildTextTile(
//                     title: 'Login',
//                     textStyle: buildTitleStyle,
//                   ),
//                   SizedBox(
//                     height: height * .08,
//                   ),
//                   Form(
//                     key: _formKey,
//                     child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         children: [
//                           SizedBox(
//                             width: size.width / 2,
//                             child: Padding(
//                               padding:
//                                   const EdgeInsets.symmetric(horizontal: 25),
//                               child: TextFormField(
//                                 autovalidateMode:
//                                     AutovalidateMode.onUserInteraction,
//                                 validator: validateEmail,
//                                 key: const Key("Phone_Number_Sign_in"),
//                                 cursorColor: ColorManager.kPrimaryColor,
//                                 controller: _emailController,
//                                 onTap: () {
//                                   Provider.of<KeyboardProvider>(context,
//                                           listen: false)
//                                       .show('email', _emailController);
//                                 },
//                                 inputFormatters: <TextInputFormatter>[
//                                   FilteringTextInputFormatter.allow(
//                                       RegExp("[0-9@a-zA-Z.]")),
//                                 ],
//                                 keyboardType: TextInputType.emailAddress,
//                                 decoration: decoration.copyWith(
//                                   prefixIcon: Icon(
//                                     Icons.email_rounded,
//                                     color: ColorManager.kPrimaryColor
//                                         .withOpacity(0.5),
//                                   ),
//                                   hintText: '*****@domain.com',
//                                   hintStyle: buildTextFieldStyle,
//                                   errorBorder: const OutlineInputBorder(
//                                     borderSide: BorderSide(
//                                       color: Colors.red,
//                                       width: 2.0,
//                                     ),
//                                   ),
//                                   focusedErrorBorder: const OutlineInputBorder(
//                                     borderSide: BorderSide(
//                                       color: Colors.red,
//                                       width: 2.0,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(
//                             height: 30,
//                           ),
//                           SizedBox(
//                             width: size.width / 2,
//                             child: Padding(
//                               padding:
//                                   const EdgeInsets.symmetric(horizontal: 25),
//                               child: TextFormField(
//                                 key: const Key("Password_Sign_in"),
//                                 obscureText: _obscureText,
//                                 cursorColor: ColorManager.kPrimaryColor,
//                                 controller: _passwordTextController,
//                                 onTap: () {
//                                   Provider.of<KeyboardProvider>(context,
//                                           listen: false)
//                                       .show(
//                                           'password', _passwordTextController);
//                                 },
//                                 // validator:
//                                 //     validatePassword, // Add validator here
//                                 decoration: decoration.copyWith(
//                                   hintText: '*******',
//                                   iconColor: ColorManager.kPrimaryWithOpacity10,
//                                   prefixIcon: Icon(
//                                     Icons.lock_clock_rounded,
//                                     color: ColorManager.kPrimaryColor
//                                         .withOpacity(0.5),
//                                   ),
//                                   hintStyle: buildTextFieldStyle,
//                                   suffixIcon: GestureDetector(
//                                     onTap: () {
//                                       setState(() {
//                                         _obscureText = !_obscureText;
//                                       });
//                                     },
//                                     child: Icon(
//                                       _obscureText
//                                           ? Icons.visibility_off
//                                           : Icons.visibility,
//                                       color: ColorManager.kPrimaryColor
//                                           .withOpacity(0.5),
//                                     ),
//                                   ),
//                                   errorBorder: const OutlineInputBorder(
//                                     borderSide: BorderSide(
//                                       color: Colors.red,
//                                       width: 2.0,
//                                     ),
//                                   ),
//                                   focusedErrorBorder: const OutlineInputBorder(
//                                     borderSide: BorderSide(
//                                       color: Colors.red,
//                                       width: 2.0,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           SizedBox(
//                             width: size.width / 2,
//                             child: Padding(
//                               padding: const EdgeInsets.all(30.0),
//                               child: Row(
//                                 mainAxisAlignment:
//                                     MainAxisAlignment.spaceBetween,
//                                 children: [
//                                   Row(
//                                     children: [
//                                       GestureDetector(
//                                         onTap: () {
//                                           setState(() {
//                                             _rememberMe = !_rememberMe;
//                                             _handleRememberMe(_rememberMe);
//                                           });
//                                         },
//                                         child: Container(
//                                           height: height * 0.02,
//                                           width: width * 0.02,
//                                           decoration: BoxDecoration(
//                                             shape: BoxShape.circle,
//                                             border: _rememberMe
//                                                 ? null
//                                                 : Border.all(
//                                                     color: ColorManager.grey,
//                                                     width: 2.0),
//                                             color: _rememberMe
//                                                 ? ColorManager.kPrimaryColor
//                                                 : Colors.white,
//                                           ),
//                                           child: _rememberMe
//                                               ? const Icon(
//                                                   Icons.check,
//                                                   size: 10,
//                                                   color: Colors.white,
//                                                 )
//                                               : null,
//                                         ),
//                                       ),
//                                       const Text(
//                                         'Remember Me',
//                                         style: TextStyle(
//                                           fontWeight: FontWeightManager.regular,
//                                           fontFamily: FontConstants.fontFamily,
//                                           fontSize: FontSize.s8,
//                                           letterSpacing: 0.12,
//                                           color: Colors.black,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   TextButton(
//                                     onPressed: () {
//                                       Navigator.push(
//                                           context,
//                                           MaterialPageRoute(
//                                               builder: (context) =>
//                                                   const ForgotPasswordScreen()));
//                                     },
//                                     child: const Text(
//                                       'Forgot Password?',
//                                       style: TextStyle(
//                                         fontWeight: FontWeightManager.medium,
//                                         fontFamily: FontConstants.fontFamily,
//                                         fontSize: FontSize.s10,
//                                         letterSpacing: 0.16,
//                                         color: ColorManager.kPrimaryColor,
//                                       ),
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           isLoading
//                               ? const Center(
//                                   child: CircularProgressIndicator(
//                                     color: ColorManager.kPrimaryColor,
//                                   ),
//                                 )
//                               : Padding(
//                                   padding: const EdgeInsets.symmetric(
//                                       horizontal: 25, vertical: 5),
//                                   child: CustomRoundButton(
//                                     width: width / 2,
//                                     fontSize: FontSize.s12,
//                                     height: size.height * .07,
//                                     key: const Key("Button_Sign_in"),
//                                     title: 'Continue',
//                                     fct: () async {
//                                       if (_formKey.currentState!.validate()) {
//                                         // debugPrint("hello");
//                                         showDialog(
//                                             context: context,
//                                             barrierDismissible: false,
//                                             builder: (context) {
//                                               return const Center(
//                                                 child: CircularProgressIndicator
//                                                     .adaptive(),
//                                               );
//                                             });
//                                         await AuthenticationProvider()
//                                             .login(
//                                                 _emailController.text,
//                                                 _passwordTextController.text,
//                                                 context)
//                                             .then((value) async {
//                                           if (value["status"] == "success") {
//                                             ExecutiveModel executiveModel =
//                                                 ExecutiveModel.fromJson(value);
//                                             ExecutiveModelData?
//                                                 executiveModelData =
//                                                 executiveModel.data;

//                                             authModel.login(
//                                                 executiveModelData
//                                                         ?.accessToken ??
//                                                     "",
//                                                 executiveModelData?.userId ??
//                                                     0);
//                                             SharedPreferenceProvider()
//                                                 .saveAccessTokenandCustomerId(
//                                                     executiveModelData
//                                                             ?.accessToken ??
//                                                         "",
//                                                     executiveModelData
//                                                             ?.userId ??
//                                                         0,
//                                                     executiveModelData
//                                                             ?.userName ??
//                                                         "");
//                                             SalesProvider salesProvider =
//                                                 Provider.of<SalesProvider>(
//                                                     context,
//                                                     listen: false);
//                                             salesProvider.setUserId(
//                                               executiveModelData?.userId ?? 0,
//                                             );
//                                             debugPrint(
//                                                 " authmodel token ${authModel.token}");
//                                             debugPrint(
//                                                 " authmodel token ${authModel.token}");
//                                             InvoiceProvider invoiceProvider =
//                                                 Provider.of<InvoiceProvider>(
//                                                     context,
//                                                     listen: false);
//                                             PurchaseProvider purchaseProvider =
//                                                 Provider.of<PurchaseProvider>(
//                                                     context,
//                                                     listen: false);
//                                             invoiceProvider
//                                                 .listAllInvoiceAccountTypes(
//                                                     authModel.token ?? '');
//                                             invoiceProvider.listAllPaymentList(
//                                                 authModel.token ?? '');
//                                             invoiceProvider
//                                                 .listVoucherAccountType(
//                                                     authModel.token ?? '');
//                                             invoiceProvider.listUsersList(
//                                                 authModel.token ?? '');
//                                             purchaseProvider.listAllStores(
//                                                 authModel.token ?? '', null);
//                                             purchaseProvider.listAllSuppliers(
//                                                 authModel.token ?? '', null);
//                                             purchaseProvider.listAllUnits(
//                                                 authModel.token ?? '');

//                                             showScaffold(
//                                               context: context,
//                                               message: '${value["message"]}',
//                                             );

//                                             await Provider.of<
//                                                         LocalProductProvider>(
//                                                     context,
//                                                     listen: false)
//                                                 .fetchProductsFromAPI();

//                                             // Load document configurations during login
//                                             try {
//                                               final docConfigProvider = Provider
//                                                   .of<DocumentConfigProvider>(
//                                                       context,
//                                                       listen: false);
//                                               await docConfigProvider
//                                                   .fetchDocumentConfigurations(
//                                                       accessToken:
//                                                           authModel.token ??
//                                                               "");
//                                               debugPrint(
//                                                   "Document configurations loaded successfully during login");
//                                             } catch (e) {
//                                               debugPrint(
//                                                   "Warning: Failed to load document configurations during login: $e");
//                                               // Don't block login if document config fails
//                                             }

//                                             // Load categories during login
//                                             try {
//                                               final categoryProvider = Provider
//                                                   .of<CategoryProvider>(
//                                                       context,
//                                                       listen: false);
//                                               await categoryProvider.listAllCategory();
//                                               debugPrint(
//                                                   "Categories loaded successfully during login");
//                                             } catch (e) {
//                                               debugPrint(
//                                                   "Warning: Failed to load categories during login: $e");
//                                               // Don't block login if categories fail
//                                             }

//                                             Navigator.pop(context);

//                                             await Future.delayed(
//                                                     const Duration(seconds: 1))
//                                                 .then((value) => Navigator.push(
//                                                     context,
//                                                     MaterialPageRoute(
//                                                         builder: (context) =>
//                                                             const MainScreen())));
//                                           } else {
//                                             Navigator.pop(context);
//                                             showScaffoldError(
//                                               context: context,
//                                               message: '${value["message"]}',
//                                             );
//                                           }
//                                         });
//                                       } else {
//                                         showScaffoldError(
//                                             context: context,
//                                             message: 'Please Fill Details!');
//                                       }
//                                     },
//                                   ),
//                                 ),
//                           // Reset API Key Button
//                           const SizedBox(height: 20),
//                           SizedBox(
//                             width: size.width / 2,
//                             child: Padding(
//                               padding: const EdgeInsets.symmetric(horizontal: 25),
//                               child: TextButton.icon(
//                                 onPressed: _resetApiKey,
//                                 icon: const Icon(
//                                   Icons.refresh,
//                                   size: 16,
//                                   color: ColorManager.kPrimaryColor,
//                                 ),
//                                 label: const Text(
//                                   'Reset API Key',
//                                   style: TextStyle(
//                                     fontWeight: FontWeightManager.medium,
//                                     fontFamily: FontConstants.fontFamily,
//                                     fontSize: FontSize.s10,
//                                     letterSpacing: 0.16,
//                                     color: ColorManager.kPrimaryColor,
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ]),
//                   ),
//                 ]),
//           ),
//         ),
//       ),
//     );
//   }

//   bool validateAndSave() {
//     final form = _formKey.currentState;
//     if (form!.validate()) {
//       form.save();
//       return true;
//     }
//     return false;
//   }

//   String? validateEmail(String? value) {
//     const pattern = r"(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'"
//         r'*+/=?^_`{|}~-]+)*|"(?:[\x01-\x08\x0b\x0c\x0e-\x1f\x21\x23-\x5b\x5d-'
//         r'\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])*")@(?:(?:[a-z0-9](?:[a-z0-9-]*'
//         r'[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\[(?:(?:(2(5[0-5]|[0-4]'
//         r'[0-9])|1[0-9][0-9]|[1-9]?[0-9]))\.){3}(?:(2(5[0-5]|[0-4][0-9])|1[0-9]'
//         r'[0-9]|[1-9]?[0-9])|[a-z0-9-]*[a-z0-9]:(?:[\x01-\x08\x0b\x0c\x0e-\x1f\'
//         r'x21-\x5a\x53-\x7f]|\\[\x01-\x09\x0b\x0c\x0e-\x7f])+)\])';
//     final regex = RegExp(pattern);

//     if (value == null || value.isEmpty) {
//       return 'Email is required';
//     }

//     if (!regex.hasMatch(value)) {
//       return 'Enter a valid email address';
//     }

//     return null;
//   }

//   String? validatePassword(String? value) {
//     if (value == null || value.isEmpty) {
//       return 'Password is required';
//     }
//     RegExp regex =
//         RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
//     if (!regex.hasMatch(value)) {
//       return 'Enter a valid password';
//     }
//     return null;
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pos_machine/components/build_dialog_box.dart';
import 'package:pos_machine/components/main_screen.dart';
import 'package:pos_machine/controllers/sidebar_controller.dart';
import 'package:pos_machine/models/executive.dart';
import 'package:pos_machine/providers/authentication_providers.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';
import 'package:pos_machine/providers/shared_preferences.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/screens/login/forgot_password.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../components/build_round_button.dart';
import '../../components/build_title.dart';
import '../../providers/auth_model.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';

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
  String _loadingMessage = 'Loading data...';

  @override
  void initState() {
    super.initState();
    _loadUserEmailPassword();
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
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('api_key');
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/api-key');
      }
    } catch (e) {
      if (mounted) {
        showScaffoldError(
          context: context,
          message: 'Failed to reset API key. Please try again.',
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
    final authModel = Provider.of<AuthModel>(context);
    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                        title: 'Login',
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
                                    onTap: () {
                                      Provider.of<KeyboardProvider>(context,
                                          listen: false)
                                          .show('email', _emailController);
                                    },
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
                                      hintText: '*****@domain.com',
                                      hintStyle: buildTextFieldStyle,
                                      errorBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 2.0,
                                        ),
                                      ),
                                      focusedErrorBorder: const OutlineInputBorder(
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
                                width: size.width / 2,
                                child: Padding(
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 25),
                                  child: TextFormField(
                                    key: const Key("Password_Sign_in"),
                                    obscureText: _obscureText,
                                    cursorColor: ColorManager.kPrimaryColor,
                                    controller: _passwordTextController,
                                    onTap: () {
                                      Provider.of<KeyboardProvider>(context,
                                          listen: false)
                                          .show(
                                          'password', _passwordTextController);
                                    },
                                    // validator:
                                    //     validatePassword, // Add validator here
                                    decoration: decoration.copyWith(
                                      hintText: '*******',
                                      iconColor: ColorManager.kPrimaryWithOpacity10,
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
                                      focusedErrorBorder: const OutlineInputBorder(
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
                                width: size.width / 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(30.0),
                                  child: Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _rememberMe = !_rememberMe;
                                                _handleRememberMe(_rememberMe);
                                              });
                                            },
                                            child: Container(
                                              height: height * 0.02,
                                              width: width * 0.02,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: _rememberMe
                                                    ? null
                                                    : Border.all(
                                                    color: ColorManager.grey,
                                                    width: 2.0),
                                                color: _rememberMe
                                                    ? ColorManager.kPrimaryColor
                                                    : Colors.white,
                                              ),
                                              child: _rememberMe
                                                  ? const Icon(
                                                Icons.check,
                                                size: 10,
                                                color: Colors.white,
                                              )
                                                  : null,
                                            ),
                                          ),
                                          const Text(
                                            'Remember Me',
                                            style: TextStyle(
                                              fontWeight: FontWeightManager.regular,
                                              fontFamily: FontConstants.fontFamily,
                                              fontSize: FontSize.s8,
                                              letterSpacing: 0.12,
                                              color: Colors.black,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                  const ForgotPasswordScreen()));
                                        },
                                        child: const Text(
                                          'Forgot Password?',
                                          style: TextStyle(
                                            fontWeight: FontWeightManager.medium,
                                            fontFamily: FontConstants.fontFamily,
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
                                  width: width / 2,
                                  fontSize: FontSize.s12,
                                  height: size.height * .07,
                                  key: const Key("Button_Sign_in"),
                                  title: 'Continue',
                                  fct: () async {
                                    if (_formKey.currentState!.validate()) {
                                      // Show our new loading overlay instead of the dialog
                                      _updateLoadingState(true, "Logging in...");
                                      
                                      // Save remember me state when login button is pressed
                                      _handleRememberMe(_rememberMe);
                                      
                                      try {
                                        final value = await AuthenticationProvider()
                                            .login(
                                                _emailController.text,
                                                _passwordTextController.text,
                                                context);

                                        if (value["status"] == "success") {
                                          ExecutiveModel executiveModel =
                                              ExecutiveModel.fromJson(value);
                                          ExecutiveModelData?
                                              executiveModelData =
                                              executiveModel.data;

                                          authModel.login(
                                              executiveModelData
                                                      ?.accessToken ??
                                                  "",
                                              executiveModelData?.userId ??
                                                  0);
                                          SharedPreferenceProvider()
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
                                                      "");
                                          SalesProvider salesProvider =
                                              Provider.of<SalesProvider>(
                                                  context,
                                                  listen: false);
                                          salesProvider.setUserId(
                                            executiveModelData?.userId ?? 0,
                                          );
                                          debugPrint(
                                              " authmodel token ${authModel.token}");
                                          debugPrint(
                                              " authmodel token ${authModel.token}");
                                          InvoiceProvider invoiceProvider =
                                              Provider.of<InvoiceProvider>(
                                                  context,
                                                  listen: false);
                                          PurchaseProvider purchaseProvider =
                                              Provider.of<PurchaseProvider>(
                                                  context,
                                                  listen: false);
                                          
                                          // Show loading indicator for data fetching
                                          _updateLoadingState(true, "Loading invoice data...");
                                          invoiceProvider
                                              .listAllInvoiceAccountTypes(
                                              authModel.token ?? '');
                                          
                                          _updateLoadingState(true, "Loading payment methods...");
                                          invoiceProvider.listAllPaymentList(
                                              authModel.token ?? '');
                                          
                                          _updateLoadingState(true, "Loading voucher data...");
                                          invoiceProvider
                                              .listVoucherAccountType(
                                              authModel.token ?? '');
                                          
                                          _updateLoadingState(true, "Loading users...");
                                          invoiceProvider.listUsersList(
                                              authModel.token ?? '');
                                          
                                          _updateLoadingState(true, "Loading stores...");
                                          purchaseProvider.listAllStores(
                                              authModel.token ?? '', null);
                                          
                                          _updateLoadingState(true, "Loading suppliers...");
                                          purchaseProvider.listAllSuppliers(
                                              authModel.token ?? '', null);
                                          
                                          _updateLoadingState(true, "Loading units...");
                                          purchaseProvider.listAllUnits(
                                              authModel.token ?? '');
                                          
                                          purchaseProvider.listMasterDataValues(
                                              authModel.token ?? '', 'RACKS');

                                          showScaffold(
                                            context: context,
                                            message: '${value["message"]}',
                                          );

                                          _updateLoadingState(true, "Loading products...");
                                          await Provider.of<
                                              LocalProductProvider>(
                                              context,
                                              listen: false)
                                              .fetchProductsFromAPI();

                                          // Load document configurations during login
                                          try {
                                            _updateLoadingState(true, "Loading document configurations...");
                                            final docConfigProvider = Provider
                                                .of<DocumentConfigProvider>(
                                                context,
                                                listen: false);
                                            await docConfigProvider
                                                .fetchDocumentConfigurations(
                                                accessToken:
                                                authModel.token ??
                                                    "");
                                            debugPrint(
                                                "Document configurations loaded successfully during login");
                                          } catch (e) {
                                            debugPrint(
                                                "Warning: Failed to load document configurations during login: $e");
                                            // Don't block login if document config fails
                                          }

                                          // Load categories during login (align with Category page)
                                          try {
                                            _updateLoadingState(true, "Loading categories...");
                                            final categoryProvider = Provider
                                                .of<CategoryProvider>(
                                                context,
                                                listen: false);
                                            await categoryProvider.searchAllCategory(page: 1);
                                            debugPrint(
                                                "Categories loaded successfully during login");
                                          } catch (e) {
                                            debugPrint(
                                                "Warning: Failed to load categories during login: $e");
                                            // Don't block login if categories fail
                                          }

                                          _updateLoadingState(false, "");

                                          // Set appropriate home page based on user role
                                          SideBarController sideBarController = Get.put(SideBarController());
                                          String userRole = executiveModelData?.userRole ?? "";
                                          
                                          switch (userRole) {
                                            case 'attender':
                                              sideBarController.index.value = 55; // Restaurant Page
                                              break;
                                            case 'kitchen_master':
                                              sideBarController.index.value = 56; // Kitchen Master Page
                                              break;
                                            case 'sales_executive':
                                            default:
                                              sideBarController.index.value = 46; // Billing Page (Home for sales executive)
                                              break;
                                          }

                                          await Future.delayed(
                                              const Duration(seconds: 1))
                                              .then((value) => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      const MainScreen())));
                                        } else {
                                          _updateLoadingState(false, "");
                                          showScaffoldError(
                                            context: context,
                                            message: '${value["message"]}',
                                          );
                                        }
                                      } catch (e) {
                                        _updateLoadingState(false, "");
                                        showScaffoldError(
                                          context: context,
                                          message: 'Login failed: ${e.toString()}',
                                        );
                                      }
                                    } else {
                                      showScaffoldError(
                                          context: context,
                                          message: 'Please Fill Details!');
                                    }
                                  },
                                ),
                              ),
                              // Reset API Key Button
                              const SizedBox(height: 20),
                              SizedBox(
                                width: size.width / 2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 25),
                                  child: TextButton.icon(
                                    onPressed: _resetApiKey,
                                    icon: const Icon(
                                      Icons.refresh,
                                      size: 16,
                                      color: ColorManager.kPrimaryColor,
                                    ),
                                    label: const Text(
                                      'Reset API Key',
                                      style: TextStyle(
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
      return 'Email is required';
    }

    if (!regex.hasMatch(value)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    RegExp regex =
    RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$');
    if (!regex.hasMatch(value)) {
      return 'Enter a valid password';
    }
    return null;
  }
}