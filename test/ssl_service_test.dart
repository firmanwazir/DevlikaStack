import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/models/site_model.dart';
import 'package:server_app/services/config_service.dart';
import 'package:server_app/services/ssl_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('devlika_ssl_test_');
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

  group('SSL & PKI Service Tests', () {
    test('buildRequiredDomains includes standard defaults and site-specific wildcards', () {
      final ssl = SslService.instance;
      final sites = [
        SiteModel(
          id: '1',
          domain: 'rabmentor.id',
          rootPath: r'D:\WebServer\laragon\www\rabmentor\public',
          type: 'php',
        ),
        SiteModel(
          id: '2',
          domain: 'siakad.univrab',
          rootPath: r'D:\WebServer\www\siakad',
          type: 'php',
        ),
      ];

      final domains = ssl.buildRequiredDomains(sites);

      // Core defaults
      expect(domains.contains('localhost'), isTrue);
      expect(domains.contains('*.local'), isTrue);
      expect(domains.contains('*.test'), isTrue);
      expect(domains.contains('*.dev'), isTrue);

      // Site domains
      expect(domains.contains('rabmentor.id'), isTrue);
      expect(domains.contains('*.rabmentor.id'), isTrue);
      expect(domains.contains('siakad.univrab'), isTrue);
      expect(domains.contains('*.siakad.univrab'), isTrue);
    });

    test('getCoveredDomains correctly reads from domains.json', () {
      final ssl = SslService.instance;
      final sslDir = Directory(ConfigService.instance.sslDir);
      sslDir.createSync(recursive: true);

      final domainsFile = File(ssl.domainsJsonPath);
      domainsFile.writeAsStringSync(jsonEncode(['localhost', 'demo.local', 'rabmentor.id']));

      final covered = ssl.getCoveredDomains();
      expect(covered.contains('localhost'), isTrue);
      expect(covered.contains('demo.local'), isTrue);
      expect(covered.contains('rabmentor.id'), isTrue);
      expect(covered.contains('uncovered.domain'), isFalse);
    });

    test('hasCertificate checks for ca.crt, server.crt, and server.key', () {
      final ssl = SslService.instance;
      expect(ssl.hasCertificate, isFalse);

      final sslDir = Directory(ConfigService.instance.sslDir);
      sslDir.createSync(recursive: true);

      File(ssl.caCertPath).writeAsStringSync('CA CERT');
      File(ssl.certPath).writeAsStringSync('SERVER CERT');
      File(ssl.keyPath).writeAsStringSync('SERVER KEY');

      expect(ssl.hasCertificate, isTrue);
    });
  });
}
