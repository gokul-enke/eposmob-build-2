import 'package:flutter/material.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/local_product_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/services/local_sale_sync_service.dart';
import 'package:provider/provider.dart';

class LocalSalesServices {
  LocalSalesServices.capture(BuildContext context)
      : products = context.read<LocalProductProvider>(),
        sync = context.read<LocalSaleSyncService>(),
        auth = context.read<AuthModel>(),
        store = context.read<StoreSessionProvider>(),
        settings = context.read<AppSettingsProvider>();
  final LocalProductProvider products;
  final LocalSaleSyncService sync;
  final AuthModel auth;
  final StoreSessionProvider store;
  final AppSettingsProvider settings;
}
