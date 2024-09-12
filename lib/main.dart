import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:pos_machine/providers/auth_model.dart';

import 'package:pos_machine/providers/cart_provider.dart';
import 'package:pos_machine/providers/category_providers.dart';
import 'package:pos_machine/providers/cart.dart';
import 'package:pos_machine/providers/customer_provider.dart';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Get.put(SideBarController());
  // SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight])
  //     .then((_) {
  //   runApp(const MyApp());
  // });
  // SystemChrome.setPreferredOrientations(
  //     [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  // SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.portraitUp,
  //   DeviceOrientation.portraitDown,
  // ]);
  if (!kIsWeb) {
    if (Platform.isMacOS) {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    }
  }

  Get.put(CategoryProvider());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
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
      ],
      child: GetMaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter POS Machine',
        theme: ThemeData(),
        home: const SignInScreen(), //const SignInScreen(),YourBag(),
      ),
    );
  }
}
