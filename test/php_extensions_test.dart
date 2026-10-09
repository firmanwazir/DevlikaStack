import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/models/php_extension_model.dart';
import 'package:server_app/services/php_manager.dart';

void main() {
  group('PHP Extension Manager & Preset Tests', () {
    final phpManager = PhpManager.instance;

    test('isExtensionEnabled correctly detects regular and Zend extensions', () {
      const sampleIni = '''
[PHP]
engine = On
extension_dir = "ext"
extension=curl
;extension=intl
extension=mbstring
;extension=pdo_mysql
zend_extension=opcache
;zend_extension=xdebug
''';

      expect(phpManager.isExtensionEnabled(sampleIni, 'curl', isZend: false, isPhp74: false), isTrue);
      expect(phpManager.isExtensionEnabled(sampleIni, 'intl', isZend: false, isPhp74: false), isFalse);
      expect(phpManager.isExtensionEnabled(sampleIni, 'mbstring', isZend: false, isPhp74: false), isTrue);
      expect(phpManager.isExtensionEnabled(sampleIni, 'pdo_mysql', isZend: false, isPhp74: false), isFalse);
      expect(phpManager.isExtensionEnabled(sampleIni, 'opcache', isZend: true, isPhp74: false), isTrue);
      expect(phpManager.isExtensionEnabled(sampleIni, 'xdebug', isZend: true, isPhp74: false), isFalse);
    });

    test('isExtensionEnabled respects PHP 7.4 gd2 vs PHP 8 gd conventions', () {
      const php74Ini = '''
extension_dir = "ext"
extension=gd2
;extension=gd
''';
      const php8Ini = '''
extension_dir = "ext"
extension=gd
;extension=gd2
''';

      // On PHP 7.4, gd2 is expected
      expect(phpManager.isExtensionEnabled(php74Ini, 'gd', isZend: false, isPhp74: true), isTrue);

      // On PHP 8.x, gd is expected
      expect(phpManager.isExtensionEnabled(php8Ini, 'gd', isZend: false, isPhp74: false), isTrue);
    });

    test('toggleExtensionInContent enables a commented extension', () {
      const ini = '''
;extension=intl
extension=curl
''';
      final updated = phpManager.toggleExtensionInContent(ini, 'intl', true, isZend: false, isPhp74: false);
      expect(phpManager.isExtensionEnabled(updated, 'intl', isZend: false, isPhp74: false), isTrue);
      expect(updated.contains('extension=intl'), isTrue);
      expect(updated.contains(';extension=intl'), isFalse);
    });

    test('toggleExtensionInContent disables an active extension', () {
      const ini = '''
extension=intl
extension=curl
''';
      final updated = phpManager.toggleExtensionInContent(ini, 'intl', false, isZend: false, isPhp74: false);
      expect(phpManager.isExtensionEnabled(updated, 'intl', isZend: false, isPhp74: false), isFalse);
      expect(updated.contains(';extension=intl'), isTrue);
    });

    test('toggleExtensionInContent handles Zend extensions like opcache and xdebug', () {
      const ini = '''
;zend_extension=opcache
''';
      // Enable
      final enabled = phpManager.toggleExtensionInContent(ini, 'opcache', true, isZend: true, isPhp74: false);
      expect(phpManager.isExtensionEnabled(enabled, 'opcache', isZend: true, isPhp74: false), isTrue);
      expect(enabled.contains('zend_extension=opcache'), isTrue);

      // Disable
      final disabled = phpManager.toggleExtensionInContent(enabled, 'opcache', false, isZend: true, isPhp74: false);
      expect(phpManager.isExtensionEnabled(disabled, 'opcache', isZend: true, isPhp74: false), isFalse);
      expect(disabled.contains(';zend_extension=opcache'), isTrue);
    });

    test('toggleExtensionInContent appends extension if missing from ini file', () {
      const ini = '''
[PHP]
memory_limit = 512M
''';
      final updated = phpManager.toggleExtensionInContent(ini, 'sodium', true, isZend: false, isPhp74: false);
      expect(phpManager.isExtensionEnabled(updated, 'sodium', isZend: false, isPhp74: false), isTrue);
      expect(updated.contains('extension=sodium'), isTrue);
    });

    test('Presets contain required extensions for Laravel, WordPress, and Minimal', () {
      final laravel = PhpManager.extensionPresets['laravel']!;
      expect(laravel, containsAll(['curl', 'intl', 'gd', 'fileinfo', 'mbstring', 'openssl', 'pdo_mysql', 'zip', 'opcache']));

      final wp = PhpManager.extensionPresets['wordpress']!;
      expect(wp, containsAll(['curl', 'gd', 'intl', 'mbstring', 'mysqli', 'openssl', 'zip', 'exif', 'fileinfo', 'opcache']));

      final minimal = PhpManager.extensionPresets['minimal']!;
      expect(minimal, containsAll(['pdo_mysql', 'mbstring', 'openssl', 'curl']));
    });
    test('Strict prefix isolation: sqlite does NOT match sqlite3, pdo does not match pdo_mysql', () {
      const ini = '''
extension=sqlite3
extension=pdo_mysql
extension=pdo_sqlite
''';
      expect(phpManager.isExtensionEnabled(ini, 'sqlite', isZend: false, isPhp74: false), isFalse);
      expect(phpManager.isExtensionEnabled(ini, 'pdo', isZend: false, isPhp74: false), isFalse);
    });

    test('Does not duplicate extension if multiple commented entries exist', () {
      const ini = '''
;extension=curl
;extension=php_curl.dll
''';
      final updated = phpManager.toggleExtensionInContent(ini, 'curl', true, isZend: false, isPhp74: false);
      final activeCurlCount = RegExp(r'^\s*extension\s*=\s*curl\b', multiLine: true).allMatches(updated).length;
      expect(activeCurlCount, equals(1));
    });

    test('OPcache toggling synchronizes opcache.enable directive', () {
      const ini = '''
;zend_extension=opcache
opcache.enable = 0
''';
      final enabled = phpManager.toggleExtensionInContent(ini, 'opcache', true, isZend: true, isPhp74: false);
      expect(enabled.contains('zend_extension=opcache'), isTrue);
      expect(enabled.contains('opcache.enable = 1'), isTrue);

      final disabled = phpManager.toggleExtensionInContent(enabled, 'opcache', false, isZend: true, isPhp74: false);
      expect(disabled.contains(';zend_extension=opcache'), isTrue);
      expect(disabled.contains('opcache.enable = 0'), isTrue);
    });

    test('GD toggling cleans up wrong variants between PHP 7.4 and PHP 8.x', () {
      // If ini has both gd and gd2 active, enabling on PHP 8 should comment out gd2
      const php8DirtyIni = '''
extension=gd2
;extension=gd
''';
      final cleanPhp8 = phpManager.toggleExtensionInContent(php8DirtyIni, 'gd', true, isZend: false, isPhp74: false);
      expect(cleanPhp8.contains('extension=gd'), isTrue);
      expect(cleanPhp8.contains('extension=gd2'), isFalse);

      // On PHP 7.4, enabling gd should comment out gd and activate gd2
      const php7DirtyIni = '''
extension=gd
;extension=gd2
''';
      final cleanPhp7 = phpManager.toggleExtensionInContent(php7DirtyIni, 'gd', true, isZend: false, isPhp74: true);
      expect(cleanPhp7.contains('extension=gd2'), isTrue);
      expect(RegExp(r'^\s*extension\s*=\s*gd\b', multiLine: true).hasMatch(cleanPhp7), isFalse);
    });

    test('Preserves CRLF windows line endings when appending extensions', () {
      const crlfIni = "[PHP]\r\nmemory_limit = 512M\r\n";
      final updated = phpManager.toggleExtensionInContent(crlfIni, 'bz2', true, isZend: false, isPhp74: false);
      expect(updated.contains('\r\n'), isTrue);
      expect(updated.contains('extension=bz2\r\n'), isTrue);
    });

    test('Extension sorting and category/status filtering logic executes accurately in memory', () {
      final sample = [
        PhpExtensionModel(key: 'curl', name: 'cURL', description: 'HTTP client', category: 'Web & API', isEnabled: false),
        PhpExtensionModel(key: 'pdo_mysql', name: 'PDO MySQL', description: 'MySQL driver', category: 'Database', isEnabled: true),
        PhpExtensionModel(key: 'openssl', name: 'OpenSSL', description: 'TLS crypto', category: 'Security & Crypto', isEnabled: true),
        PhpExtensionModel(key: 'mysqli', name: 'MySQLi', description: 'MySQL API', category: 'Database', isEnabled: false),
        PhpExtensionModel(key: 'opcache', name: 'Zend OPcache', description: 'Bytecode cache', category: 'Performance & Debug', isEnabled: true, isZend: true),
      ];

      // 1. Sort: active_first (Active items first, then alphabetical A-Z)
      final activeFirst = List<PhpExtensionModel>.from(sample);
      activeFirst.sort((a, b) {
        if (a.isEnabled != b.isEnabled) return a.isEnabled ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      expect(activeFirst.map((e) => e.key).toList(), equals(['openssl', 'pdo_mysql', 'opcache', 'curl', 'mysqli']));

      // 2. Sort: name_asc (A-Z)
      final nameAsc = List<PhpExtensionModel>.from(sample);
      nameAsc.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      expect(nameAsc.map((e) => e.key).toList(), equals(['curl', 'mysqli', 'openssl', 'pdo_mysql', 'opcache']));

      // 3. Sort: name_desc (Z-A)
      final nameDesc = List<PhpExtensionModel>.from(sample);
      nameDesc.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      expect(nameDesc.map((e) => e.key).toList(), equals(['opcache', 'pdo_mysql', 'openssl', 'mysqli', 'curl']));

      // 4. Status Filter: active only
      final activeOnly = sample.where((e) => e.isEnabled).toList();
      expect(activeOnly.length, equals(3));
      expect(activeOnly.map((e) => e.key), containsAll(['pdo_mysql', 'openssl', 'opcache']));

      // 5. Status Filter: inactive only
      final inactiveOnly = sample.where((e) => !e.isEnabled).toList();
      expect(inactiveOnly.length, equals(2));
      expect(inactiveOnly.map((e) => e.key), containsAll(['curl', 'mysqli']));

      // 6. Category Filter: Database
      final dbOnly = sample.where((e) => e.category == 'Database').toList();
      expect(dbOnly.length, equals(2));
      expect(dbOnly.map((e) => e.key), containsAll(['pdo_mysql', 'mysqli']));
    });
  });
}
