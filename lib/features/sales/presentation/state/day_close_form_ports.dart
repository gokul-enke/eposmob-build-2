import 'package:flutter/material.dart';
import 'package:pos_machine/features/sales/presentation/state/sales_provider.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/master_data_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:provider/provider.dart';

class DayCloseFormPorts {
  DayCloseFormPorts(
      {required this.master,
      required this.auth,
      required this.settings,
      required this.store,
      required this.sales});
  DayCloseFormPorts.capture(BuildContext context)
      : master = context.read<MasterDataProvider>(),
        auth = context.read<AuthModel>(),
        settings = context.read<AppSettingsProvider>(),
        store = context.read<StoreSessionProvider>(),
        sales = context.read<SalesProvider>();
  final MasterDataProvider master;
  final AuthModel auth;
  final AppSettingsProvider settings;
  final StoreSessionProvider store;
  final SalesProvider sales;
}
