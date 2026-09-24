import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pos_machine/components/software_info_dialog.dart';

void main() {
  testWidgets('shows software name and installed version before login',
      (tester) async {
    final packageInfo = PackageInfo(
      appName: 'CLOUDPOS',
      packageName: 'com.enke.cloudposai',
      version: '1.0.60',
      buildNumber: '70',
    );

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => SoftwareInfoDialog(
              packageInfoFuture: Future.value(packageInfo),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Software Information'), findsOneWidget);
    expect(find.text('Software:'), findsOneWidget);
    expect(find.text('CLOUDPOS'), findsOneWidget);
    expect(find.text('Version:'), findsOneWidget);
    expect(find.text('1.0.60.70'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(SoftwareInfoDialog), findsNothing);
  });

  testWidgets('shows a fallback when package information cannot be read',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => SoftwareInfoDialog(
              packageInfoFuture: Future<PackageInfo>.delayed(
                Duration.zero,
                () => throw Exception('failed'),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Not available'), findsOneWidget);
  });
}
