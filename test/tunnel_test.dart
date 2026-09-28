import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/services/config_service.dart';
import 'package:server_app/services/tunnel_service.dart';

void main() {
  group('Cloudflare Tunnel Service Tests', () {
    test('ConfigService has cloudflaredExe configured properly', () {
      final config = ConfigService.instance;
      expect(config.cloudflaredExe, contains('cloudflared.exe'));
      expect(config.cloudflaredExe, contains('bin'));
    });

    test('TunnelService starts in idle state', () {
      final tunnel = TunnelService.instance;
      expect(tunnel.isRunning, isFalse);
      expect(tunnel.isStarting, isFalse);
      expect(tunnel.publicUrl, isNull);
      expect(tunnel.activeDomain, isNull);
    });

    test('Cloudflare Quick Tunnel regex extracts valid trycloudflare URL', () {
      const sampleStderr = '''
2026-09-28T09:30:00Z INF +--------------------------------------------------------------------------------------------+
2026-09-28T09:30:00Z INF |  Your quick Tunnel has been created! Visit it at (it may take some time to be reachable):  |
2026-09-28T09:30:00Z INF |  https://alpha-beta-gamma-123.trycloudflare.com                                            |
2026-09-28T09:30:00Z INF +--------------------------------------------------------------------------------------------+
''';

      final reg = RegExp(r'https://[a-zA-Z0-9-]+\.trycloudflare\.com');
      final match = reg.firstMatch(sampleStderr);
      expect(match, isNotNull);
      expect(match!.group(0), equals('https://alpha-beta-gamma-123.trycloudflare.com'));
    });

    test('stopTunnel resets active state safely', () async {
      final tunnel = TunnelService.instance;
      await tunnel.stopTunnel();
      expect(tunnel.isRunning, isFalse);
      expect(tunnel.isStarting, isFalse);
      expect(tunnel.publicUrl, isNull);
    });
  });
}
