import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/services/config_service.dart';
import 'package:server_app/services/vhost_config_generator.dart';
import 'package:server_app/services/php_manager.dart';

void main() {
  group('Multi-PHP Version & FastCGI Routing Tests', () {
    test('normalizePhpVersionKey normalizes version variations accurately', () {
      expect(ConfigService.normalizePhpVersionKey('7.4'), equals('7.4'));
      expect(ConfigService.normalizePhpVersionKey('7'), equals('7.4'));
      expect(ConfigService.normalizePhpVersionKey('php-7.4'), equals('7.4'));
      expect(ConfigService.normalizePhpVersionKey('php7.4'), equals('7.4'));
      expect(ConfigService.normalizePhpVersionKey('7.4.33'), equals('7.4'));

      expect(ConfigService.normalizePhpVersionKey('8.1'), equals('8.1'));
      expect(ConfigService.normalizePhpVersionKey('php-8.1'), equals('8.1'));

      expect(ConfigService.normalizePhpVersionKey('8.2'), equals('8.2'));
      expect(ConfigService.normalizePhpVersionKey('8'), equals('8.2'));
      expect(ConfigService.normalizePhpVersionKey('php-8.2'), equals('8.2'));

      expect(ConfigService.normalizePhpVersionKey('8.3'), equals('8.3'));
      expect(ConfigService.normalizePhpVersionKey('default'), equals('default'));
      expect(ConfigService.normalizePhpVersionKey(null), equals('default'));
      expect(ConfigService.normalizePhpVersionKey(''), equals('default'));
    });

    test('VhostConfigGenerator.getFastCgiPort maps each PHP version to dedicated port', () {
      expect(VhostConfigGenerator.getFastCgiPort('7.4'), equals(9074));
      expect(VhostConfigGenerator.getFastCgiPort('7'), equals(9074));
      expect(VhostConfigGenerator.getFastCgiPort('php-7.4'), equals(9074));

      expect(VhostConfigGenerator.getFastCgiPort('8.1'), equals(9081));
      expect(VhostConfigGenerator.getFastCgiPort('8.2'), equals(9082));
      expect(VhostConfigGenerator.getFastCgiPort('8.3'), equals(9083));
      expect(VhostConfigGenerator.getFastCgiPort('default'), equals(9000));
    });

    test('ConfigService.getPhpForSite resolves 7.4 strictly to PHP 7.4 and never falls back to PHP 8.2 when 7.4 is available', () {
      final php74 = ConfigService.instance.getPhpForSite('7.4');
      expect(php74.versionKey, equals('7.4'));
      expect(php74.dirPath.toLowerCase(), contains('7.4'));

      final php7Fuzzy = ConfigService.instance.getPhpForSite('7');
      expect(php7Fuzzy.versionKey, equals('7.4'));

      final php82 = ConfigService.instance.getPhpForSite('8.2');
      expect(php82.versionKey, equals('8.2'));
    });
  });
}
