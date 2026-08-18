import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../components/build_round_button.dart';
import '../../components/build_title.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/helpers/system_keyboard_policy.dart';
import 'package:pos_machine/helpers/debug_login_autofill.dart';
import 'package:pos_machine/services/tenant_domain_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({
    super.key,
    this.initialError,
  });

  final String? initialError;

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final FocusNode _apiKeyFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscureText = true;

  bool _shouldSuppressSystemKeyboard() {
    return SystemKeyboardPolicy.shouldSuppressForContext(
      context: context,
      fieldWantsVirtualKeyboardOnly: true,
    );
  }

  void _ensureVirtualKeyboardOffByDefault() {
    try {
      final keyboardProvider =
          Provider.of<KeyboardProvider>(context, listen: false);
      keyboardProvider.featureOff();
      keyboardProvider.clear();
      _apiKeyFocusNode.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialError;
    // Keep virtual keyboard off on first open; re-apply after Hive may finish loading.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVirtualKeyboardOffByDefault();
      _loadExistingApiKey();
      Future<void>.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _ensureVirtualKeyboardOffByDefault();
      });
    });
  }

  Future<void> _loadExistingApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final savedApiKey = prefs.getString('api_key')?.trim();
    if (savedApiKey != null && savedApiKey.isNotEmpty) {
      _apiKeyController.text = savedApiKey;
    } else {
      await DebugLoginAutofill.applyApiKeyIfNeeded(_apiKeyController);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _apiKeyFocusNode.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndSaveApiKey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final tenantKey = _apiKeyController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await TenantDomainService.discoverAndSave(tenantKey);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on TenantDomainException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateApiKey(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'login.validator_api_key_required'.tr;
    }
    if (value.trim().length < 10) {
      return 'login.validator_api_key_short'.tr;
    }
    return null;
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
                      SizedBox(height: titleTopSpace),
                      BuildTextTile(
                        title: 'login.api_key_title'.tr,
                        textStyle: buildTitleStyle,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'login.api_key_subtitle'.tr,
                        style: buildCustomStyle(
                          FontWeightManager.regular,
                          FontSize.s14,
                          0.27,
                          Colors.black.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: betweenTitleAndForm),
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
                                  focusNode: _apiKeyFocusNode,
                                  autofocus: false,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  validator: _validateApiKey,
                                  cursorColor: ColorManager.kPrimaryColor,
                                  controller: _apiKeyController,
                                  obscureText: _obscureText,
                                  readOnly: _shouldSuppressSystemKeyboard(),
                                  showCursor: true,
                                  onTap: () {
                                    final keyboardProvider =
                                        Provider.of<KeyboardProvider>(context,
                                            listen: false);
                                    if (keyboardProvider.showKeyboardFeature) {
                                      keyboardProvider.show(
                                          'api_key', _apiKeyController);
                                    }
                                  },
                                  keyboardType: TextInputType.text,
                                  decoration: decoration.copyWith(
                                    prefixIcon: Icon(
                                      Icons.key,
                                      color: ColorManager.kPrimaryColor
                                          .withOpacity(0.5),
                                    ),
                                    hintText: 'login.api_key_hint'.tr,
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
                            const SizedBox(height: 20),
                            if (_errorMessage != null)
                              Container(
                                width: formWidth,
                                margin: fieldPadding,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: FontSize.s12,
                                    fontFamily: FontConstants.fontFamily,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            const SizedBox(height: 30),
                            _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: ColorManager.kPrimaryColor,
                                    ),
                                  )
                                : Padding(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 16 : 25,
                                        vertical: 5),
                                    child: CustomRoundButton(
                                      width: formWidth,
                                      fontSize: FontSize.s12,
                                      height: size.height * .07,
                                      title: 'login.btn_submit'.tr,
                                      fct: _verifyAndSaveApiKey,
                                      isLoading: _isLoading,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'login.api_key_no_key'.tr,
                            style: buildCustomStyle(
                              FontWeightManager.regular,
                              FontSize.s14,
                              0.27,
                              Colors.black.withOpacity(0.6),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('https://cloudposai.com');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            child: Text(
                              'login.api_key_register'.tr,
                              style: buildCustomStyle(
                                FontWeightManager.semiBold,
                                FontSize.s14,
                                0.27,
                                ColorManager.kPrimaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Keyboard toggle button (top-right)
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
        ],
      ),
    );
  }
}
