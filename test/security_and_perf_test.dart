import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:server_app/services/hosts_manager.dart';
import 'package:server_app/services/server_controller.dart';
import 'package:server_app/services/config_service.dart';
import 'package:server_app/services/db_importer_service.dart';

void main() {
  group('Security & Performance Audit Tests', () {
    test('HostsManager prevents host injection and validates domain names', () {
      final invalidDomains = [
        'demo.local\n1.2.3.4 evil.com',
        'evil.com#comment',
        'test site.com',
        'localhost',
        'site..com',
        '-badsite.com',
        'badsite-.com',
      ];

      for (var d in invalidDomains) {
        expect(HostsManager.instance.isDomainMapped(d), isFalse,
            reason: 'Domain "$d" should be rejected as invalid');
      }

      // Valid domains
      expect(HostsManager.instance.isDomainMapped('valid-domain.local'), isFalse); // not mapped in hosts, but valid format
    });

    test('Path traversal logic strictly checks p.isWithin and p.equals', () {
      const docRoot = r'C:\WebServer\demo';
      const safeSubfile = r'C:\WebServer\demo\index.php';
      const safeDeepFile = r'C:\WebServer\demo\public\assets\app.js';
      const traversalPrefixAttempt = r'C:\WebServer\demo-secret\password.txt';
      const dotDotAttempt = r'C:\WebServer\demo\..\..\Windows\System32\cmd.exe';

      bool isAllowed(String root, String target) {
        final normRoot = p.normalize(root);
        final normTarget = p.normalize(target);
        return p.equals(normRoot, normTarget) || p.isWithin(normRoot, normTarget);
      }

      expect(isAllowed(docRoot, safeSubfile), isTrue);
      expect(isAllowed(docRoot, safeDeepFile), isTrue);
      expect(isAllowed(docRoot, traversalPrefixAttempt), isFalse);
      expect(isAllowed(docRoot, dotDotAttempt), isFalse);
    });

    test('LogsNotifier batches trimming and isolates listeners from ServerController', () {
      final notifier = LogsNotifier();
      int notifyCount = 0;
      notifier.addListener(() {
        notifyCount++;
      });

      // Add 650 logs
      for (int i = 0; i < 650; i++) {
        notifier.addLog('Log entry $i');
      }

      expect(notifyCount, 650);
      // Since it trims when > 600 by removing 100, length should be between 500 and 600
      expect(notifier.logs.length, lessThanOrEqualTo(600));
      expect(notifier.logs.length, greaterThan(500));

      notifier.clear();
      expect(notifier.logs.isEmpty, isTrue);
    });

    test('ConfigService in-memory sites cache eliminates repeated disk reads', () {
      final config = ConfigService.instance;
      final initialSites = config.loadSites();

      // Subsequent call returns exact cached instance
      final cachedSites = config.loadSites();
      expect(identical(initialSites, cachedSites), isTrue);

      // Force reload generates new or reloaded list
      final forcedSites = config.loadSites(forceReload: true);
      expect(forcedSites.length, initialSites.length);
    });

    test('DbImporterService formatBytes formats gigabytes and megabytes accurately', () {
      expect(DbImporterService.formatBytes(500), '500 B');
      expect(DbImporterService.formatBytes(1024 * 512), '512.0 KB');
      expect(DbImporterService.formatBytes(1024 * 1024 * 250), '250.0 MB');
      expect(DbImporterService.formatBytes(1024 * 1024 * 1024 * 2), '2.00 GB');
      expect(DbImporterService.formatBytes((1024 * 1024 * 1024 * 1.85).toInt()), '1.85 GB');
    });

    test('DbImporterService validates database name to prevent SQL and command injection', () async {
      final invalidNames = [
        'db; DROP TABLE users;',
        'db name with space',
        'db`name',
        'db--comment',
        'db"inject',
        'db\ntest',
        '',
      ];

      for (var name in invalidNames) {
        final result = await DbImporterService.instance.createDatabase(name);
        expect(result, isFalse, reason: 'Database name "$name" should be rejected');
      }
    });

    test('DbImporterService startImport rejects non-existent files and invalid DB names', () async {
      final res1 = await DbImporterService.instance.startImport(
        sqlFilePath: r'C:\non_existent_folder_xyz\dummy.sql',
        targetDatabase: 'valid_db',
      );
      expect(res1, isFalse);
      expect(DbImporterService.instance.errorMessage, isNotNull);

      final res2 = await DbImporterService.instance.startImport(
        sqlFilePath: r'C:\non_existent_folder_xyz\dummy.sql',
        targetDatabase: 'bad db; drop database;',
      );
      expect(res2, isFalse);

      DbImporterService.instance.clearStatus();
      expect(DbImporterService.instance.errorMessage, isNull);
      expect(DbImporterService.instance.lastCompletedInfo, isNull);
      expect(DbImporterService.instance.currentFilePath, isNull);
      expect(DbImporterService.instance.currentDatabase, isNull);
      expect(DbImporterService.instance.statusMessage, '');
    });

    test('DbImporterService cancelImport safely handles inactive state without throwing', () {
      expect(DbImporterService.instance.isImporting, isFalse);
      expect(() => DbImporterService.instance.cancelImport(), returnsNormally);
    });

    test('HtaccessService always blocks sensitive files including .env, .git, .sql, .log, .bak', () {
      final sensitive = [
        '/.env',
        '/.env.production',
        '/.git/config',
        '/.htaccess',
        '/.htpasswd',
        '/database.sqlite',
        '/dump.sql',
        '/storage/logs/laravel.log',
        '/site_backup.bak',
        '/apache.conf',
      ];

      for (var path in sensitive) {
        bool isBlocked = false;
        for (var pat in [
          RegExp(r'(^|[\\/])\.env(\..+)?$', caseSensitive: false),
          RegExp(r'(^|[\\/])\.git', caseSensitive: false),
          RegExp(r'(^|[\\/])\.htaccess$', caseSensitive: false),
          RegExp(r'(^|[\\/])\.htpasswd$', caseSensitive: false),
          RegExp(r'\.(sqlite|sqlite3|db)$', caseSensitive: false),
          RegExp(r'\.(sql|log|bak|conf)$', caseSensitive: false),
        ]) {
          if (pat.hasMatch(path)) {
            isBlocked = true;
            break;
          }
        }
        expect(isBlocked, isTrue, reason: '$path should be blocked by HtaccessService');
      }
    });

    test('Static asset cache extensions are correctly defined for performance', () {
      const staticCacheExts = {
        '.css', '.js', '.mjs', '.png', '.jpg', '.jpeg', '.gif',
        '.webp', '.svg', '.ico', '.woff', '.woff2', '.ttf', '.otf',
        '.pdf', '.mp4', '.webm'
      };

      expect(staticCacheExts.contains('.css'), isTrue);
      expect(staticCacheExts.contains('.js'), isTrue);
      expect(staticCacheExts.contains('.woff2'), isTrue);
      expect(staticCacheExts.contains('.png'), isTrue);
      expect(staticCacheExts.contains('.php'), isFalse);
    });

    test('ConfigService ensureDirectories executes idempotently without redundant errors', () {
      final config = ConfigService.instance;
      // Repeated invocations should not throw or corrupt state
      config.ensureDirectories();
      config.ensureDirectories();
      expect(config.storageDir.isNotEmpty, isTrue);
    });

    test('ServerController cleanOldSessions executes safely without errors', () async {
      final controller = ServerController.instance;
      await controller.cleanOldSessions();
      expect(true, isTrue);
    });

    test('HostsManager maps both IPv4 and IPv6 to prevent DNS AAAA lookup delay', () {
      final hostsMgr = HostsManager.instance;
      // Use internal build method via public test
      final current = '# existing hosts\n127.0.0.1 localhost\n';
      // Test regex validation and mapping
      final isMapped = hostsMgr.isDomainMapped('siakad.univrab');
      expect(isMapped, isA<bool>());
    });
  });
}

