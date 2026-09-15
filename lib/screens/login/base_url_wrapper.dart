import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pos_machine/screens/login/api_key_screen.dart';
import 'package:pos_machine/services/tenant_startup_resolver.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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
      final result = await TenantStartupResolver.resolve();
      if (mounted) {
        setState(() => _destination = result.needsApiKey
            ? ApiKeyScreen(initialError: result.error)
            : const SignInScreen());
      }
    } catch (error, stackTrace) {
      // The user only sees a generic message; keep the real cause.
      debugPrint('⚠️ Could not load login configuration: $error\n$stackTrace');
      unawaited(Sentry.captureException(error, stackTrace: stackTrace));
      if (mounted) {
        setState(() => _destination = ApiKeyScreen(
              initialError: 'base_url_wrapper.error_load_config'.tr,
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
