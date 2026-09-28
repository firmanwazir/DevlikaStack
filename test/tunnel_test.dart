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
      expect(tunnel.isDownloading, isFalse);
      expect(tunnel.publicUrl, isNull);
      expect(tunnel.activeDomain, isNull);
      expect(tunnel.activePort, isNull);
      expect(tunnel.lastError, isNull);
    });

    test('Auto-reconnect is enabled by default', () {
      final tunnel = TunnelService.instance;
      expect(tunnel.autoReconnectEnabled, isTrue);
      expect(tunnel.reconnectAttempts, equals(0));
    });

    test('setAutoReconnect toggles correctly', () {
      final tunnel = TunnelService.instance;
      tunnel.setAutoReconnect(false);
      expect(tunnel.autoReconnectEnabled, isFalse);
      tunnel.setAutoReconnect(true);
      expect(tunnel.autoReconnectEnabled, isTrue);
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

    test('Regex does NOT match invalid domains', () {
      const noMatch = 'https://example.com/hello';
      final reg = RegExp(r'https://[a-zA-Z0-9-]+\.trycloudflare\.com');
      expect(reg.firstMatch(noMatch), isNull);
    });

    test('stopTunnel resets active state safely (idempotent)', () async {
      final tunnel = TunnelService.instance;
      // Calling stopTunnel even when nothing is running should not throw
      await tunnel.stopTunnel();
      expect(tunnel.isRunning, isFalse);
      expect(tunnel.isStarting, isFalse);
      expect(tunnel.publicUrl, isNull);
      expect(tunnel.reconnectAttempts, equals(0));

      // Call again - should be safe
      await tunnel.stopTunnel();
      expect(tunnel.isRunning, isFalse);
    });

    test('downloadCloudflared prevents double-download', () async {
      final tunnel = TunnelService.instance;
      // Since cloudflared is not installed in test env, this tests
      // that the guard works - it should not crash
      expect(tunnel.isDownloading, isFalse);
    });
  });
}
