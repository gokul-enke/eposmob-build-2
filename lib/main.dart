import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:pos_machine/providers/app_settings_provider.dart';

import 'package:pos_machine/providers/auth_model.dart';

import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/cart.dart';
import 'package:pos_machine/providers/customer_provider.dart';
import 'package:pos_machine/providers/delivery_methods_provider.dart';
import 'package:pos_machine/providers/general_settings_provider.dart';

import 'package:pos_machine/providers/grid_provider.dart';

import 'package:pos_machine/providers/invoice_provider.dart';
import 'package:pos_machine/providers/location_provider.dart';

import 'package:pos_machine/providers/report_provider.dart';
import 'package:pos_machine/providers/sales_provider.dart';

import 'package:provider/provider.dart';

import 'controllers/sidebar_controller.dart';
import 'providers/carousel_provider.dart';
import 'providers/purchase_provider.dart';

import 'screens/login/login.dart';
import 'screens/base_url_wrapper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Get.put(SideBarController());

  if (!kIsWeb) {
    if (Platform.isMacOS) {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    }
  }

  Get.put(CategoryProvider());
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => GridSelectionProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => Cart()),
        ChangeNotifierProvider(create: (_) => CarouselProvider()),
        ChangeNotifierProvider(create: (_) => SalesProvider()),
        ChangeNotifierProvider(create: (_) => AuthModel()),
        ChangeNotifierProvider(create: (_) => PurchaseProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => ReportsProvider()),
        ChangeNotifierProvider(create: (_) => GeneralSettingsProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProvider(create: (_) => DeliveryMethodsProvider()),
      ],
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter POS Machine',
        theme: ThemeData(),
        home: const BaseUrlWrapper(),
        routes: {
          '/login': (context) => const SignInScreen(),
        },
      ),
    );
  }
}
