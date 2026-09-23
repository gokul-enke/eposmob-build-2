import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_machine/features/weigh_machine/data/plu_export_service.dart';
import 'package:pos_machine/models/get_product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory documents;
  final service = PluExportService.instance;
  final originalDocuments = service.documentsDirectory;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('plu_documents_');
    service.documentsDirectory = () async => documents;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    service.documentsDirectory = originalDocuments;
    await documents.delete(recursive: true);
  });

  String defaultPath() =>
      [documents.path, 'epos', 'PLU'].join(Platform.pathSeparator);

  test('defaults to Documents/epos/PLU and creates it', () async {
    expect(Directory(defaultPath()).existsSync(), isFalse);

    expect(await service.directoryPath(), defaultPath());
    expect(Directory(defaultPath()).existsSync(), isTrue);
    expect(await service.usesCustomDirectory(), isFalse);

    final file = await service.export([
      GetProduct(productId: 1, productName: 'Apples'),
    ]);
    expect(file.path, '${defaultPath()}${Platform.pathSeparator}PLU.csv');
    expect(file.existsSync(), isTrue);
  });

  test('a chosen folder wins until reset to the default', () async {
    final chosen =
        await Directory('${documents.path}${Platform.pathSeparator}scale')
            .create();

    await service.setDirectoryPath(chosen.path);
    expect(await service.directoryPath(), chosen.path);
    expect(await service.usesCustomDirectory(), isTrue);

    await service.resetDirectoryPath();
    expect(await service.directoryPath(), defaultPath());
    expect(await service.usesCustomDirectory(), isFalse);
  });
}
