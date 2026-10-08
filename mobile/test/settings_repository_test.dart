import 'package:field_notes/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default note status persists locally and starts at OPEN', () async {
    SharedPreferences.setMockInitialValues({});
    final first = SettingsRepository(await SharedPreferences.getInstance());
    expect(first.defaultStatus(), 'OPEN');
    await first.setDefaultStatus('COMPLETED');

    final reloaded = SettingsRepository(await SharedPreferences.getInstance());
    expect(reloaded.defaultStatus(), 'COMPLETED');
    expect(SettingsRepository.key, 'default_note_status');
  });
}
