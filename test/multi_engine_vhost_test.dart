import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/models/site_model.dart';
import 'package:server_app/services/config_service.dart';
import 'package:server_app/services/vhost_config_generator.dart';
import 'package:server_app/services/web_server_engine_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('devlikastack_test_');
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

  group('Multi-Engine VHost & Architecture Tests', () {
    test('ConfigService defaults activeWebEngine to builtin and persists switches', () {
      final config = ConfigService.instance;
      expect(config.activeWebEngine, equals('builtin'));

      config.setActiveWebEngine('nginx');
      expect(config.activeWebEngine, equals('nginx'));

      config.setActiveWebEngine('apache');
      expect(config.activeWebEngine, equals('apache'));

      config.setActiveWebEngine('builtin');
      expect(config.activeWebEngine, equals('builtin'));
    });

    test('VhostConfigGenerator produces valid Nginx configuration files', () async {
      final config = ConfigService.instance;
      final generator = VhostConfigGenerator.instance;

      final testSites = [
        SiteModel(
          id: '1',
          domain: 'laravelsite.test',
          rootPath: r'D:\WebServer\www\laravelsite',
          phpVersion: '8.2',
          isEnabled: true,
          type: 'php',
        ),
        SiteModel(
          id: '2',
          domain: 'nodesite.test',
          rootPath: r'D:\WebServer\www\nodesite',
          proxyPort: 3000,
          isEnabled: true,
          type: 'proxy',
        ),
        SiteModel(
          id: '3',
          domain: 'disabled.test',
          rootPath: r'D:\WebServer\www\disabled',
          isEnabled: false,
          type: 'php',
        ),
      ];

      await generator.generateNginxConfigs(testSites);

      // Verify main nginx.conf exists
      final mainConf = File(config.nginxConfFile);
      expect(mainConf.existsSync(), isTrue);
      final mainContent = mainConf.readAsStringSync();
      expect(mainContent.contains('include vhosts/*.conf;'), isTrue);
      expect(mainContent.contains('/__phpmyadmin'), isTrue);
      expect(mainContent.contains('127.0.0.1:9000'), isTrue);

      // Verify helper files exist
      expect(File('${config.nginxConfDir}/mime.types').existsSync(), isTrue);
      expect(File('${config.nginxConfDir}/fastcgi_params').existsSync(), isTrue);

      // Verify vhost file for laravelsite.test
      final laravelConf = File('${config.nginxVhostsDir}/laravelsite.test.conf');
      expect(laravelConf.existsSync(), isTrue);
      final laravelContent = laravelConf.readAsStringSync();
      expect(laravelContent.contains('server_name laravelsite.test;'), isTrue);
      expect(laravelContent.contains('fastcgi_pass   127.0.0.1:9082;'), isTrue);
      expect(laravelContent.contains('try_files \$uri \$uri/ /index.php?\$query_string;'), isTrue);
      // Ensure path is converted to forward slashes (no Windows backslash in nginx config)
      expect(laravelContent.contains(r'D:\WebServer'), isFalse);
      expect(laravelContent.contains('D:/WebServer/www/laravelsite'), isTrue);

      // Verify vhost file for proxy site nodesite.test
      final nodeConf = File('${config.nginxVhostsDir}/nodesite.test.conf');
      expect(nodeConf.existsSync(), isTrue);
      final nodeContent = nodeConf.readAsStringSync();
      expect(nodeContent.contains('proxy_pass http://127.0.0.1:3000;'), isTrue);
      expect(nodeContent.contains('proxy_set_header Upgrade'), isTrue);

      // Verify disabled site is NOT generated
      final disabledConf = File('${config.nginxVhostsDir}/disabled.test.conf');
      expect(disabledConf.existsSync(), isFalse);
    });

    test('VhostConfigGenerator produces valid Apache HTTPD configuration', () async {
      final config = ConfigService.instance;
      final generator = VhostConfigGenerator.instance;

      final testSites = [
        SiteModel(
          id: '1',
          domain: 'tokoonline.test',
          rootPath: r'D:\WebServer\www\tokoonline',
          phpVersion: '8.2',
          isEnabled: true,
          type: 'php',
        ),
        SiteModel(
          id: '2',
          domain: 'apiservice.test',
          rootPath: r'D:\WebServer\www\apiservice',
          proxyPort: 8080,
          isEnabled: true,
          type: 'proxy',
        ),
      ];

      await generator.generateApacheConfigs(testSites);

      final apacheConf = File(config.apacheVhostsFile);
      expect(apacheConf.existsSync(), isTrue);
      final content = apacheConf.readAsStringSync();

      // Check default localhost & phpMyAdmin
      expect(content.contains('<VirtualHost *:80>'), isTrue);
      expect(content.contains('ServerName localhost'), isTrue);
      expect(content.contains('Alias /__phpmyadmin'), isTrue);

      // Check tokoonline.test
      expect(content.contains('ServerName tokoonline.test'), isTrue);
      expect(content.contains('DocumentRoot "D:/WebServer/www/tokoonline"'), isTrue);
      expect(content.contains('SetHandler "proxy:fcgi://127.0.0.1:9000"'), isTrue);

      // Check proxy apiservice.test
      expect(content.contains('ServerName apiservice.test'), isTrue);
      expect(content.contains('ProxyPass / http://127.0.0.1:8080/'), isTrue);
      expect(content.contains('ProxyPassReverse / http://127.0.0.1:8080/'), isTrue);
    });

    test('WebServerEngineManager switches engines and updates display name', () async {
      final engineMgr = WebServerEngineManager.instance;

      expect(await engineMgr.switchEngine('nginx'), isTrue);
      expect(engineMgr.activeEngine, equals('nginx'));
      expect(engineMgr.activeEngineDisplayName, equals('Nginx 1.26 Portable'));

      expect(await engineMgr.switchEngine('apache'), isTrue);
      expect(engineMgr.activeEngine, equals('apache'));
      expect(engineMgr.activeEngineDisplayName, equals('Apache HTTPD 2.4'));

      expect(await engineMgr.switchEngine('builtin'), isTrue);
      expect(engineMgr.activeEngine, equals('builtin'));
      expect(engineMgr.activeEngineDisplayName, equals('Devlika Native HTTP Engine'));

      // Rejects invalid engine name
      expect(await engineMgr.switchEngine('iis'), isFalse);
    });

    test('VhostConfigGenerator auto-detects public_html folder when present', () async {
      final config = ConfigService.instance;
      final generator = VhostConfigGenerator.instance;

      final testProject = Directory('${tempDir.path}/legacy_siakad');
      final publicHtml = Directory('${testProject.path}/public_html')..createSync(recursive: true);
      File('${publicHtml.path}/index.php').writeAsStringSync('<?php echo "ok";');

      final site = SiteModel(
        id: 'siak-1',
        domain: 'siakad.test',
        rootPath: testProject.path,
        phpVersion: '7.4',
        isEnabled: true,
        type: 'php',
      );

      await generator.generateNginxConfigs([site]);
      final vhost = File('${config.nginxVhostsDir}/siakad.test.conf').readAsStringSync();
      expect(vhost.contains('root "${testProject.path.replaceAll(r'\', '/')}/public_html";'), isTrue);
    });

    test('VhostConfigGenerator configures SSL port 443 in Nginx and Apache when certificate is present', () async {
      final config = ConfigService.instance;
      final generator = VhostConfigGenerator.instance;

      // Mock cert and key files in tempDir/storage/ssl
      final sslDir = Directory(config.sslDir)..createSync(recursive: true);
      File(config.sslCertFile).writeAsStringSync('-----BEGIN CERTIFICATE-----\nMOCK\n-----END CERTIFICATE-----');
      File(config.sslKeyFile).writeAsStringSync('-----BEGIN PRIVATE KEY-----\nMOCK\n-----END PRIVATE KEY-----');

      final site = SiteModel(
        id: 'ssl-site-1',
        domain: 'secure.test',
        rootPath: '${tempDir.path}/secure',
        phpVersion: '8.2',
        isEnabled: true,
        type: 'php',
      );

      await generator.generateNginxConfigs([site]);
      final nginxVhost = File('${config.nginxVhostsDir}/secure.test.conf').readAsStringSync();
      expect(nginxVhost.contains('listen 443 ssl;'), isTrue);
      expect(nginxVhost.contains('ssl_certificate'), isTrue);

      await generator.generateApacheConfigs([site]);
      final apacheVhost = File(config.apacheVhostsFile).readAsStringSync();
      expect(apacheVhost.contains('<VirtualHost *:443>'), isTrue);
      expect(apacheVhost.contains('SSLEngine on'), isTrue);
    });

    test('SecurityContext loads generated Devlika Stack SSL certificate and private key', () {
      final certFile = File(r'D:\WebServer\www\WindowApp\Server\DevlikaStack-Portable\bin\storage\ssl\server.crt');
      final keyFile = File(r'D:\WebServer\www\WindowApp\Server\DevlikaStack-Portable\bin\storage\ssl\server.key');
      expect(certFile.existsSync(), isTrue);
      expect(keyFile.existsSync(), isTrue);

      final sec = SecurityContext()
        ..useCertificateChain(certFile.path)
        ..usePrivateKey(keyFile.path);
      expect(sec, isNotNull);
    });
  });
}
