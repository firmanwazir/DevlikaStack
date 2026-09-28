import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_app/services/htaccess_service.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('htaccess_test_');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('Parses and executes full user .htaccess example', () async {
    final htaccessContent = '''
Options -Indexes
Options +FollowSymlinks

RewriteEngine on
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule .* index.php/\$0 [PT,L]

php_flag log_errors on
php_value error_reporting 32767
php_value post_max_size 20M
php_value upload_max_filesize 20M
max_input_vars = 10000

<FilesMatch ".*\\.(log)\$">
    Order Deny,Allow
    Deny from all
</FilesMatch>

RewriteCond %{REQUEST_URI} ^/uploads/
RewriteRule \\.(php|php5|phtml|phar)\$ - [F,L]

<IfModule mod_headers.c>
    Header set Server2 Microsoft-IIS/8.5
    Header set X-Powered-By ASP.NET
</IfModule>

RewriteCond %{HTTP_REFERER} (viagra) [NC,OR]
RewriteCond %{HTTP_REFERER} (porno) [NC]
RewriteRule .* - [F]

RewriteCond %{HTTP_USER_AGENT} (Microsoft\\ URL\\ Control) [NC]
RewriteRule .* - [F]
''';

    File('${tempDir.path}/.htaccess').writeAsStringSync(htaccessContent);

    // Create dummy index.php
    File('${tempDir.path}/index.php').writeAsStringSync('<?php echo "ok";');

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = HtaccessService.instance.evaluate(
        request: req,
        docRoot: tempDir.path,
        rawPath: req.uri.path,
      );

      // Verify php_values
      expect(res.phpIniOverrides['post_max_size'], equals('20M'));
      expect(res.phpIniOverrides['upload_max_filesize'], equals('20M'));
      expect(res.phpIniOverrides['log_errors'], equals('1'));
      expect(res.phpIniOverrides['max_input_vars'], equals('10000'));

      // Verify headers
      expect(res.responseHeaders['Server2'], equals('Microsoft-IIS/8.5'));
      expect(res.responseHeaders['X-Powered-By'], equals('ASP.NET'));

      if (req.uri.path == '/uploads/shell.php') {
        expect(res.isForbidden, isTrue);
      } else if (req.uri.path == '/error.log') {
        expect(res.isForbidden, isTrue);
      } else if (req.uri.path == '/.env') {
        expect(res.isForbidden, isTrue);
      } else if (req.headers.value('referer') == 'http://porno.com') {
        expect(res.isForbidden, isTrue);
      } else if (req.uri.path == '/api/users') {
        expect(res.rewrittenPath, equals('/index.php'));
        expect(res.pathInfo, equals('/api/users'));
      }

      req.response.statusCode = res.isForbidden ? 403 : 200;
      await req.response.close();
    });

    final client = HttpClient();

    // 1. Test normal CI routing (/api/users -> index.php/$0)
    final req1 = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/api/users'));
    final resp1 = await req1.close();
    expect(resp1.statusCode, equals(200));

    // 2. Test blocking PHP in /uploads/
    final req2 = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/uploads/shell.php'));
    final resp2 = await req2.close();
    expect(resp2.statusCode, equals(403));

    // 3. Test FilesMatch blocking .log
    final req3 = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/error.log'));
    final resp3 = await req3.close();
    expect(resp3.statusCode, equals(403));

    // 4. Test built-in .env protection
    final req4 = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/.env'));
    final resp4 = await req4.close();
    expect(resp4.statusCode, equals(403));

    // 5. Test Referrer spam blocking
    final req5 = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/home'));
    req5.headers.set('referer', 'http://porno.com');
    final resp5 = await req5.close();
    expect(resp5.statusCode, equals(403));

    await server.close(force: true);
    client.close();
  });

  test('Parses and executes Laravel standard .htaccess', () async {
    final htaccessContent = '''
<IfModule mod_rewrite.c>
    <IfModule mod_negotiation.c>
        Options -MultiViews -Indexes
    </IfModule>

    RewriteEngine On

    # Redirect Trailing Slashes If Not A Folder...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)/\$ /\$1 [L,R=301]

    # Handle Front Controller...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]

    # Handle Authorization Header
    RewriteCond %{HTTP:Authorization} .
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]
</IfModule>
''';

    File('${tempDir.path}/.htaccess').writeAsStringSync(htaccessContent);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final res = HtaccessService.instance.evaluate(
        request: req,
        docRoot: tempDir.path,
        rawPath: req.uri.path,
      );

      if (res.isRedirect) {
        req.response.statusCode = res.redirectStatusCode;
        req.response.headers.set(HttpHeaders.locationHeader, res.redirectUrl!);
      } else {
        req.response.statusCode = 200;
        req.response.write(res.rewrittenPath);
      }
      await req.response.close();
    });

    final client = HttpClient();

    // Test trailing slash redirect: /dashboard/ -> /dashboard (301)
    final req1 = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/dashboard/'));
    req1.followRedirects = false;
    final resp1 = await req1.close();
    expect(resp1.statusCode, equals(301));
    expect(resp1.headers.value(HttpHeaders.locationHeader), equals('/dashboard'));

    // Test front controller rewrite: /api/v1/posts -> /index.php
    final req2 = await client.getUrl(Uri.parse('http://127.0.0.1:${server.port}/api/v1/posts'));
    final resp2 = await req2.close();
    expect(resp2.statusCode, equals(200));

    await server.close(force: true);
    client.close();
  });
}
