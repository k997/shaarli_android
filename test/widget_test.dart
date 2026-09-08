// This is a smoke test that builds the app's home page with mocked secure
// storage; the initial link fetch fails against the mocked (empty) config,
// which is expected and surfaces as an error snackbar.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shaarli_android/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues(const {});

  testWidgets('home page shows app bar and actions', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Let the initial link fetch fail (no config) and the UI settle.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Shaarli'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });
}
