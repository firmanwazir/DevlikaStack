import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/models/site_model.dart';
import 'package:server_app/services/config_service.dart';
import 'package:server_app/services/http_server_service.dart';

void main() {
  late Directory tempDir;
  late Directory tempSiteDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('devlika_static_test_');
    tempSiteDir = Directory('${tempDir.path}/site')..createSync(recursive: true);
    ConfigService.instance.setBinDirForTesting(tempDir.path);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('Static asset serving, 304 conditional requests, and fast 404', () async {
    // 1. Create a sample css file and index.php in the test site
    final cssFile = File('${tempSiteDir.path}/style.css');
    cssFile.writeAsStringSync('body { background: #fff; }');

    final indexPhp = File('${tempSiteDir.path}/index.php');
    indexPhp.writeAsStringSync('<?php echo "<h1>PHP Front Controller</h1>"; ?>');

    // 2. Register site in ConfigService
    final testSite = SiteModel(
      id: 'static-test-site',
      domain: 'static.test',
      rootPath: tempSiteDir.path,
      type: 'php',
      proxyPort: 3000,
      isEnabled: true,
    );
    ConfigService.instance.saveSites([testSite]);

    // Bind server on random free port
    ConfigService.instance.setHttpPort(9128);
    final started = await HttpServerService.instance.start();
    expect(started, isTrue);

    final client = HttpClient();

    // --- TEST 1: First request returns 200 OK with ETag & correct Content-Type ---
    final req1 = await client.getUrl(Uri.parse('http://127.0.0.1:9128/style.css'));
    req1.headers.set('Host', 'static.test');
    final resp1 = await req1.close();
    expect(resp1.statusCode, equals(200));
    expect(resp1.headers.contentType?.mimeType, equals('text/css'));
    final etag = resp1.headers.value('etag');
    expect(etag, isNotNull);
    final body1 = await resp1.transform(const SystemEncoding().decoder).join();
    expect(body1, contains('body { background: #fff; }'));

    // --- TEST 2: Second request with If-None-Match returns 304 without socket reset ---
    final req2 = await client.getUrl(Uri.parse('http://127.0.0.1:9128/style.css'));
    req2.headers.set('Host', 'static.test');
    req2.headers.set('If-None-Match', etag!);
    final resp2 = await req2.close();
    expect(resp2.statusCode, equals(304));
    expect(resp2.headers.value('content-length'), equals('0'));
    await resp2.drain();

    // --- TEST 3: Weak ETag (W/"...") also returns 304 ---
    final req3 = await client.getUrl(Uri.parse('http://127.0.0.1:9128/style.css'));
    req3.headers.set('Host', 'static.test');
    req3.headers.set('If-None-Match', 'W/$etag');
    final resp3 = await req3.close();
    expect(resp3.statusCode, equals(304));
    await resp3.drain();

    // --- TEST 4: Missing static asset returns 404 text/css directly (NOT index.php HTML!) ---
    final req4 = await client.getUrl(Uri.parse('http://127.0.0.1:9128/nonexistent.css'));
    req4.headers.set('Host', 'static.test');
    final resp4 = await req4.close();
    expect(resp4.statusCode, equals(404));
    expect(resp4.headers.contentType?.mimeType, equals('text/css'));
    final body4 = await resp4.transform(const SystemEncoding().decoder).join();
    expect(body4, contains('404 Not Found'));
    expect(body4, isNot(contains('PHP Front Controller')));

    await HttpServerService.instance.stop();
    client.close();
  });
}
