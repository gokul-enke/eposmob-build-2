import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../../resources/app_url.dart';
import '../../components/build_round_button.dart';
import '../../components/build_title.dart';
import '../../resources/color_manager.dart';
import '../../resources/font_manager.dart';
import '../../resources/style_manager.dart';
import 'package:provider/provider.dart';
import 'package:pos_machine/providers/keyboard_provider.dart';
import 'package:pos_machine/helpers/system_keyboard_policy.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    // Ensure on-screen keyboard feature is OFF by default when opening API key screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final keyboardProvider = Provider.of<KeyboardProvider>(context, listen: false);
        keyboardProvider.featureOff();
        keyboardProvider.clear();
      } catch (_) {}
    });
  }

  Future<void> _saveApiConfig({
    required String tenantKey,
    required String domain,
    bool usedDefaultDomain = false,
  }) async {
    String normalizedDomain = APPUrl.normalizeBaseUrl(domain);
    if (!normalizedDomain.startsWith('http://') &&
        !normalizedDomain.startsWith('https://')) {
      normalizedDomain = 'https://$normalizedDomain';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', tenantKey);
    await prefs.setString('app_url', normalizedDomain);
    await prefs.setBool('show_default_domain_warning', usedDefaultDomain);
    APPUrl.updateBaseURL(normalizedDomain);
  }

  Future<void> _saveAndContinueWithDefaultDomain(String tenantKey) async {
    await _saveApiConfig(
      tenantKey: tenantKey,
      domain: APPUrl.defaultBaseURL,
      usedDefaultDomain: true,
    );

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
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
      final response = await http.post(
        Uri.parse(APPUrl.findDomainUrl),
        headers: {
          'X-Tenant-Key': tenantKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 20));

      Map<String, dynamic> responseBody = {};
      try {
        responseBody = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      final int apiStatus =
          (responseBody['status'] is int) ? responseBody['status'] as int : -1;

      if (response.statusCode == 200 && apiStatus == 200) {
        final data = responseBody['data'];
        final String? domain =
            (data is Map<String, dynamic>) ? data['domain']?.toString() : null;

        if (domain == null || domain.trim().isEmpty) {
          await _saveAndContinueWithDefaultDomain(tenantKey);
          return;
        }

        await _saveApiConfig(
          tenantKey: tenantKey,
          domain: domain,
          usedDefaultDomain: false,
        );

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
        return;
      }

      await _saveAndContinueWithDefaultDomain(tenantKey);

    } on TimeoutException {
      await _saveAndContinueWithDefaultDomain(tenantKey);
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to verify API key. Please try again.';
      });
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
      return 'API key is required';
    }
    if (value.trim().length < 10) {
      return 'API key must be at least 10 characters';
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
                    SizedBox(height: titleTopSpace),
                    BuildTextTile(
                      title: 'API Key Required',
                      textStyle: buildTitleStyle,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Please enter your API key to continue',
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
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                validator: _validateApiKey,
                                cursorColor: ColorManager.kPrimaryColor,
                                controller: _apiKeyController,
                                obscureText: _obscureText,
                                readOnly: _shouldSuppressSystemKeyboard(),
                                showCursor: true,
                                onTap: () {
                                  Provider.of<KeyboardProvider>(context, listen: false)
                                      .show('api_key', _apiKeyController);
                                },
                                keyboardType: TextInputType.text,
                                decoration: decoration.copyWith(
                                  prefixIcon: Icon(
                                    Icons.key,
                                    color:
                                        ColorManager.kPrimaryColor.withOpacity(0.5),
                                  ),
                                  hintText: 'Enter your API key',
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
                                      horizontal: isMobile ? 16 : 25, vertical: 5),
                                  child: CustomRoundButton(
                                    width: formWidth,
                                    fontSize: FontSize.s12,
                                    height: size.height * .07,
                                    title: 'Submit',
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
                          "Don't have an API key? ",
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
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Text(
                            'Register Here',
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
                    color: Provider.of<KeyboardProvider>(context).showKeyboardFeature
                        ? ColorManager.kPrimaryColor
                        : Colors.grey.shade600,
                  ),
                  tooltip: Provider.of<KeyboardProvider>(context).showKeyboardFeature
                      ? 'Hide Keyboard'
                      : 'Show Keyboard',
                  onPressed: () {
                    final keyboardProvider = Provider.of<KeyboardProvider>(context, listen: false);
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
