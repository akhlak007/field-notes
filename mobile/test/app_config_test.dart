import 'package:field_notes/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release APK default is the public HTTPS API', () {
    expect(AppConfig.productionApiUrl, 'https://field-notes-api.onrender.com');
    expect(Uri.parse(AppConfig.productionApiUrl).isScheme('https'), isTrue);
  });
}
