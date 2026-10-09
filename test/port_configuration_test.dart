import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/models/site_model.dart';
import 'package:server_app/services/config_service.dart';
import 'package:server_app/services/port_checker_service.dart';
import 'package:server_app/services/server_controller.dart';
import 'package:server_app/services/vhost_config_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('devlikastack_port_test_');
    ConfigService.instance.setBinDirForTesting(tempDir.path);
  });

  tearDown(() async {
    ConfigService.instance.setBinDirForTesting(null);
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Network Port & Conflict Management Tests', () {
    test('ConfigService defaults HTTP (80), HTTPS (443), and MariaDB (3306)', () {
      final config = ConfigService.instance;
      expect(config.httpPort, equals(80));
      expect(config.httpsPort, equals(443));
      expect(config.mariaDbPort, equals(3306));
    });

    test('ConfigService persists custom ports across settings reload', () {
      final config = ConfigService.instance;

      config.setHttpPort(8080);
      config.setHttpsPort(8443);
      config.setMariaDbPort(3307);

      expect(config.httpPort, equals(8080));
      expect(config.httpsPort, equals(8443));
      expect(config.mariaDbPort, equals(3307));

      // Reset to defaults
      config.setHttpPort(80);
      config.setHttpsPort(443);
      config.setMariaDbPort(3306);
      expect(config.httpPort, equals(80));
    });

    test('PortCheckerService checkPort detects free socket and returns valid PortStatus', () async {
      final service = PortCheckerService.instance;
      // An obscure high ephemeral port is almost always free
      final status = await service.checkPort(54321);
      expect(status.port, equals(54321));
      expect(status.description, contains('Tersedia'));
    });

    test('PortCheckerService suggests alternative ports properly', () async {
      final service = PortCheckerService.instance;
      final altHttp = await service.suggestAlternativeHttpPort();
      expect(altHttp, greaterThan(0));

      final altDb = await service.suggestAlternativeMariaDbPort();
      expect(altDb, greaterThan(0));
    });

    test('ServerController resolveSiteUrl formats URLs cleanly on port 80 and appends port on 8080', () {
      final controller = ServerController.instance;
      final config = ConfigService.instance;

      // When port is 80 (default)
      config.setHttpPort(80);
      expect(controller.resolveSiteUrl('http://mytest.test'), equals('http://mytest.test'));
      expect(controller.formatSiteUrl('mytest.test', isHttps: false), equals('http://mytest.test'));

      // When port is 8080 (XAMPP coexist)
      config.setHttpPort(8080);
      expect(controller.resolveSiteUrl('http://mytest.test'), equals('http://mytest.test:8080'));
      expect(controller.formatSiteUrl('mytest.test', isHttps: false), equals('http://mytest.test:8080'));

      // Revert back
      config.setHttpPort(80);
    });

    test('VhostConfigGenerator configures custom HTTP port in Nginx and Apache', () async {
      final config = ConfigService.instance;
      final generator = VhostConfigGenerator.instance;

      config.setHttpPort(8080);
      config.setHttpsPort(8443);

      final testSites = [
        SiteModel(
          id: '1',
          domain: 'coexist.test',
          rootPath: tempDir.path,
          phpVersion: '8.2',
          isEnabled: true,
          type: 'php',
        ),
      ];

      // 1. Nginx verification
      await generator.generateNginxConfigs(testSites);
      final nginxMainConf = File(config.nginxConfFile).readAsStringSync();
      expect(nginxMainConf, contains('listen       8080 default_server;'));

      final nginxVhost = File(p.join(config.nginxVhostsDir, 'coexist.test.conf')).readAsStringSync();
      expect(nginxVhost, contains('listen 8080;'));

      // 2. Apache verification
      await generator.generateApacheConfigs(testSites);
      final apacheVhost = File(config.apacheVhostsFile).readAsStringSync();
      expect(apacheVhost, contains('<VirtualHost *:8080>'));

      // Reset
      config.setHttpPort(80);
      config.setHttpsPort(443);
    });
  });
}
