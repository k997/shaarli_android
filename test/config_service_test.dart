// Tests for the edit_before_save setting added for the share-to-edit flow
// (issue #1), using the plugin's mock secure storage.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shaarli_android/core/config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('editBeforeSave defaults to true when unset', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final config = ConfigService();
    expect(await config.editBeforeSave(), isTrue);
  });

  test('editBeforeSave round-trips through saveSettings', () async {
    // A growable map: saveSettings writes through the mock platform, which
    // mutates the initial values.
    FlutterSecureStorage.setMockInitialValues({});
    final config = ConfigService();

    await config.saveSettings(
        'https://example.com', 'secret', false, 'work', false);
    expect(await config.editBeforeSave(), isFalse);

    await config.saveSettings(
        'https://example.com', 'secret', false, 'work', true);
    expect(await config.editBeforeSave(), isTrue);
  });
}
