import 'package:flutter/material.dart';
import 'package:pos_machine/providers/admin_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/sync_provider.dart';
import 'package:pos_machine/features/realtime_sync/presentation/realtime_sync_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionResetService {
  static const List<String> _authScopedKeys = [
    'access_token',
    'customerId',
    'customerName',
    'userRole',
    'token_type',
  ];

  static const List<String> _tenantScopedKeys = [
    'access_token',
    'customerId',
    'customerName',
    'userRole',
    'token_type',
    'company_id',
    'company_name',
    'stores',
    'active_store_id',
    'time_zone',
    'zatca_cr_number',
    'zatca_vat_number',
    'zatca_company_name',
    'default_printer',
    'default_paper_size',
    'default_font_style',
    'quotation_printer',
    'quotation_paper_size',
    'quotation_font_style',
    'kot_printer',
    'kot_paper_size',
    'kot_font_style',
    'billing_receipt_theme',
    'quotation_receipt_theme',
    'kot_receipt_theme',
    'server_time_offset',
    'last_product_sync_iso',
    'document_configs_snapshot_json',
    'document_configs_snapshot_updated_at',
    'admin_settings_logo_url',
    'admin_settings_logo_file_path',
  ];

  static const List<String> _deviceScopedKeys = [
    'default_printer',
    'default_paper_size',
    'default_font_style',
    'default_printer_name',
    'default_printer_address',
    'quotation_printer',
    'quotation_paper_size',
    'quotation_font_style',
    'kot_printer',
    'kot_paper_size',
    'kot_font_style',
    'billing_receipt_theme',
    'quotation_receipt_theme',
    'kot_receipt_theme',
    'app_locale_code',
    'app_font_size_level',
  ];

  static Future<void> resetAfterLogout(BuildContext context) async {
    await context.read<RealtimeSyncProvider>().stop();
    final prefs = await SharedPreferences.getInstance();
    for (final key in _authScopedKeys) {
      await prefs.remove(key);
    }
    context.read<StoreSessionProvider>().resetSession();
    context.read<AuthModel>().logout();
  }

  static Future<void> resetForApiKeyReset(BuildContext context) async {
    await _reset(
      context,
      clearApiKey: true,
      clearAllPreferences: true,
      preserveRememberMe: false,
    );
  }

  static Future<void> clearLocalStorageAndLogout(
    BuildContext context, {
    bool preserveRememberMe = true,
  }) async {
    await _reset(
      context,
      clearApiKey: true,
      clearAllPreferences: true,
      preserveRememberMe: preserveRememberMe,
      preserveDeviceScopedKeys: true,
    );
  }

  static Future<void> _reset(
    BuildContext context, {
    required bool clearApiKey,
    required bool clearAllPreferences,
    required bool preserveRememberMe,
    bool preserveDeviceScopedKeys = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      await context.read<RealtimeSyncProvider>().stop();
    } catch (_) {}

    String? rememberedEmail;
    String? rememberedPassword;
    bool rememberedFlag = false;
    final String? existingApiKey = prefs.getString('api_key');
    final Map<String, Object> preservedDeviceValues = <String, Object>{};

    if (preserveRememberMe) {
      rememberedEmail = prefs.getString('emailRemember');
      rememberedPassword = prefs.getString('passwordRemember');
      rememberedFlag = prefs.getBool('remember_me') ?? false;
    }

    if (preserveDeviceScopedKeys) {
      for (final key in _deviceScopedKeys) {
        final value = prefs.get(key);
        if (value != null) {
          preservedDeviceValues[key] = value;
        }
      }
    }

    try {
      context.read<SyncProvider>().forceResetSyncState();
    } catch (_) {}

    await context.read<LocalProductProvider>().clearAllLocalData();
    await context.read<CategoryProvider>().clearAllCategories();
    await context.read<DocumentConfigProvider>().clearAllCaches();
    context.read<AdminSettingsProvider>().clear();
    context.read<StoreSessionProvider>().resetSession();

    if (clearAllPreferences) {
      await prefs.clear();
    } else {
      for (final key in _tenantScopedKeys) {
        await prefs.remove(key);
      }
    }

    final shouldClearApiKey =
        clearApiKey && !(preserveRememberMe && rememberedFlag);

    if (shouldClearApiKey) {
      await prefs.remove('api_key');
    } else if (clearAllPreferences &&
        existingApiKey != null &&
        existingApiKey.isNotEmpty) {
      await prefs.setString('api_key', existingApiKey);
    }

    if (preserveRememberMe && rememberedFlag) {
      await prefs.setBool('remember_me', true);
      if (rememberedEmail != null) {
        await prefs.setString('emailRemember', rememberedEmail);
      }
      if (rememberedPassword != null) {
        await prefs.setString('passwordRemember', rememberedPassword);
      }
    }

    if (preserveDeviceScopedKeys && preservedDeviceValues.isNotEmpty) {
      for (final entry in preservedDeviceValues.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is List<String>) {
          await prefs.setStringList(entry.key, value);
        }
      }
    }

    context.read<AuthModel>().logout();
  }
}
