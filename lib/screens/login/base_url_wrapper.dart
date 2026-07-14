import 'package:flutter/material.dart';
import 'package:pos_machine/resources/app_url.dart';
import 'package:pos_machine/screens/login/api_key_screen.dart';
import 'package:pos_machine/services/tenant_domain_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class BaseUrlWrapper extends StatefulWidget {
  const BaseUrlWrapper({super.key});

  @override
  State<BaseUrlWrapper> createState() => _BaseUrlWrapperState();
}

class _BaseUrlWrapperState extends State<BaseUrlWrapper> {
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _resolveLoginConfiguration();
  }

  Future<void> _resolveLoginConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('api_key')?.trim() ?? '';
      if (apiKey.isEmpty) {
        if (mounted) setState(() => _destination = const ApiKeyScreen());
        return;
      }

      final savedUrl = prefs.getString('app_url')?.trim() ?? '';
      final usedUnverifiedDefault =
          prefs.getBool('show_default_domain_warning') ?? false;
      final isDefaultUrl = savedUrl.isNotEmpty &&
          APPUrl.normalizeBaseUrl(savedUrl) ==
              APPUrl.normalizeBaseUrl(APPUrl.defaultBaseURL);
      final needsRepair =
          savedUrl.isEmpty || usedUnverifiedDefault || isDefaultUrl;

      if (needsRepair) {
        try {
          await TenantDomainService.discoverAndSave(apiKey);
        } on TenantDomainException catch (e) {
          if (mounted) {
            setState(() => _destination = ApiKeyScreen(
                  initialError: e.message,
                ));
          }
          return;
        }
      } else {
        APPUrl.updateBaseURL(savedUrl);
      }

      if (mounted) setState(() => _destination = const SignInScreen());
    } catch (_) {
      if (mounted) {
        setState(() => _destination = const ApiKeyScreen(
              initialError: 'Unable to load the saved login configuration.',
            ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_destination == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return _destination!;
  }
}
