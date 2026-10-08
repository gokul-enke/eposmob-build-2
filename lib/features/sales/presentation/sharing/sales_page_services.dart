import 'package:flutter/widgets.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';
import 'package:pos_machine/providers/auth_model.dart';
import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/document_config_provider.dart';
import 'package:pos_machine/providers/store_session_provider.dart';
import 'package:pos_machine/providers/whatsapp_provider.dart';
import 'package:provider/provider.dart';

import '../state/sales_provider.dart';

/// Captured by the page before asynchronous commands start.
class SalesPageServices {
  SalesPageServices.capture(BuildContext context)
      : auth = context.read<AuthModel>(),
        sales = context.read<SalesProvider>(),
        settings = context.read<AppSettingsProvider>(),
        store = context.read<StoreSessionProvider>(),
        _documents = optional<DocumentConfigProvider>(context),
        _whatsapp = optional<WhatsappProvider>(context),
        _cart = optional<CartProvider>(context);
  static T? optional<T>(BuildContext context) {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  final AuthModel auth;
  final SalesProvider sales;
  final AppSettingsProvider settings;
  final StoreSessionProvider store;
  final DocumentConfigProvider? _documents;
  final WhatsappProvider? _whatsapp;
  final CartProvider? _cart;
  DocumentConfigProvider get documents => _documents!;
  WhatsappProvider get whatsapp => _whatsapp!;
  CartProvider get cart => _cart!;
}
