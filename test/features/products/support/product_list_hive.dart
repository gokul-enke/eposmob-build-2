import 'dart:io';
import 'package:hive/hive.dart';
import 'package:pos_machine/models/local_models.dart';

Future<Directory> openProductListHive() async {
  final directory = await Directory.systemTemp.createTemp('product_list_hive_');
  Hive.init(directory.path);
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(HiveStringValueAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(HiveLocalCartItemAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(HiveSavedOrderAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(HiveProductAdapter());
  }
  await Hive.openBox<HiveProduct>('products');
  await Hive.openBox<HiveLocalCartItem>('cart_items');
  await Hive.openBox<HiveSavedOrder>('saved_orders');
  await Hive.openBox<HiveSavedOrder>('confirmed_orders');
  return directory;
}
