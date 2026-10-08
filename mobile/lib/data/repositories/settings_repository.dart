import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  SettingsRepository(this._preferences);

  static const key = 'default_note_status';
  final SharedPreferences _preferences;

  String defaultStatus() {
    final value = _preferences.getString(key);
    if (value == 'IN_PROGRESS' || value == 'COMPLETED' || value == 'OPEN') {
      return value!;
    }
    return 'OPEN';
  }

  Future<void> setDefaultStatus(String status) {
    return _preferences.setString(key, status);
  }
}
