import 'dart:io';

class DeviceIdentity {
  const DeviceIdentity({required this.name, required this.identifier});

  final String name;
  final String identifier;

  String get actorName => name;

  static Future<DeviceIdentity> detect() async {
    final name = Platform.localHostname.trim().isEmpty
        ? 'Equipo local'
        : Platform.localHostname.trim();
    final identifier = await _macAddress() ?? 'hostname:$name';
    return DeviceIdentity(name: name, identifier: identifier);
  }

  static Future<String?> _macAddress() async {
    try {
      if (Platform.isMacOS || Platform.isLinux) {
        final executable = Platform.isMacOS ? '/sbin/ifconfig' : 'ip';
        final arguments = Platform.isMacOS ? const <String>[] : const ['link'];
        final result = await Process.run(executable, arguments);
        if (result.exitCode != 0) return null;
        final match = RegExp(
          r'(?:ether|link/ether)\s+([0-9a-f]{2}(?::[0-9a-f]{2}){5})',
          caseSensitive: false,
        ).firstMatch(result.stdout.toString());
        return match?.group(1)?.toUpperCase();
      }
      if (Platform.isWindows) {
        final result = await Process.run('getmac', const ['/fo', 'csv', '/nh']);
        final match = RegExp(
          r'([0-9A-F]{2}(?:-[0-9A-F]{2}){5})',
          caseSensitive: false,
        ).firstMatch(result.stdout.toString());
        return match?.group(1)?.replaceAll('-', ':').toUpperCase();
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
