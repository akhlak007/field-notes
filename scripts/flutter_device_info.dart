import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run flutter_device_info.dart <device-id-or-name>');
    exitCode = 64;
    return;
  }

  final input = await stdin.transform(utf8.decoder).join();
  final decoded = jsonDecode(input);
  if (decoded is! List) {
    stderr.writeln('Flutter returned an unexpected device list.');
    exitCode = 2;
    return;
  }

  final needle = arguments.single.toLowerCase();
  final devices = decoded.whereType<Map>().toList();
  Map<dynamic, dynamic>? selected;

  for (final device in devices) {
    final id = '${device['id'] ?? ''}'.toLowerCase();
    final name = '${device['name'] ?? ''}'.toLowerCase();
    if (id == needle || name == needle) {
      selected = device;
      break;
    }
  }
  if (selected == null) {
    for (final device in devices) {
      final id = '${device['id'] ?? ''}'.toLowerCase();
      final name = '${device['name'] ?? ''}'.toLowerCase();
      if (id.startsWith(needle) || name.startsWith(needle)) {
        selected = device;
        break;
      }
    }
  }

  if (selected == null) {
    stderr.writeln('Could not identify Flutter device "${arguments.single}".');
    exitCode = 3;
    return;
  }

  final platform = '${selected['targetPlatform'] ?? ''}';
  final emulator = selected['emulator'] == true ? 'true' : 'false';
  stdout.write('$platform\t$emulator');
}
