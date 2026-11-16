// Widget tests for the AddItemPage prefill parameters introduced for the
// share-to-edit flow (issue #1). With every text field prefilled the
// post-frame metadata fetch is a no-op, so no network access happens.

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shaarli_android/features/add_item_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('prefills all fields from the share draft parameters',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(const {});
    await tester.pumpWidget(const MaterialApp(
      home: AddItemPage(
        initialUrl: 'https://example.com/post',
        initialTitle: 'A good article',
        initialDescription: 'Something worth reading',
        initialTags: ['work', 'news'],
        initialPrivate: false,
      ),
    ));
    // Let the post-frame metadata fetch callback run (no-op: all fields
    // prefilled).
    await tester.pump();

    expect(find.widgetWithText(TextFormField, 'https://example.com/post'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'A good article'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Something worth reading'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'work news'), findsOneWidget);

    // The draft explicitly says "public", so the switch must be off.
    final privateSwitch =
        tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(privateSwitch.value, isFalse);
  });

  testWidgets('falls back to the configured default privacy without prefill',
      (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues(const {'is_private': 'true'});
    await tester.pumpWidget(
        const MaterialApp(home: AddItemPage(initialUrl: 'https://example.com')));
    // The async default-privacy lookup resolves after the first frame.
    await tester.pump();
    await tester.pump();

    final privateSwitch =
        tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(privateSwitch.value, isTrue);
  });
}
