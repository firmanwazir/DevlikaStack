import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/site_model.dart';
import 'config_service.dart';

class SslService {
  static final SslService instance = SslService._();
  SslService._();

  String get caCertPath => ConfigService.instance.sslCaCertFile;
  String get caKeyPath => ConfigService.instance.sslCaKeyFile;
  String get certPath => ConfigService.instance.sslCertFile;
  String get fullChainCertPath => p.join(ConfigService.instance.sslDir, 'fullchain.crt');
  String get keyPath => ConfigService.instance.sslKeyFile;
  String get cnfPath => ConfigService.instance.sslCnfFile;
  String get domainsJsonPath => p.join(ConfigService.instance.sslDir, 'domains.json');

  bool get hasCertificate =>
      File(certPath).existsSync() &&
      File(keyPath).existsSync() &&
      File(caCertPath).existsSync();

  /// Reads list of domains currently covered by the generated leaf certificate.
  Set<String> getCoveredDomains() {
    final file = File(domainsJsonPath);
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is List) {
        return decoded.map((e) => e.toString().trim().toLowerCase()).toSet();
      }
    } catch (_) {}
    return {};
  }

  /// Builds the complete set of required SAN DNS names from default templates and configured sites.
  Set<String> buildRequiredDomains(List<SiteModel> sites) {
    final dnsNames = <String>{
      'localhost',
      '*.localhost',
      '*.local',
      '*.test',
      '*.univrab',
      '*.dev',
      '*.devel',
      '*.internal',
      '*.lan',
      '*.site',
      '*.app',
      'devlika.local',
      'devlika.test',
      'phpmyadmin.local',
      'phpmyadmin.test',
    };

    for (final s in sites) {
      final domain = s.domain.trim().toLowerCase();
      if (domain.isNotEmpty) {
        dnsNames.add(domain);
        if (!domain.startsWith('*.')) {
          dnsNames.add('*.$domain');
        }
      }
    }
    return dnsNames;
  }

  /// Ensures that Root CA and signed Leaf Certificate exist and cover all sites.
  /// Automatically regenerates leaf certificate if any site domain is missing.
  Future<bool> ensureCertificate({List<SiteModel>? sites, bool force = false}) async {
    final config = ConfigService.instance;
    final sslDir = Directory(config.sslDir);
    if (!sslDir.existsSync()) {
      sslDir.createSync(recursive: true);
    }

    final siteList = sites ?? config.loadSites();

    if (!force && hasCertificate) {
      final covered = getCoveredDomains();
      final required = buildRequiredDomains(siteList);
      if (covered.containsAll(required) && File(fullChainCertPath).existsSync()) {
        return true;
      }
    }

    return await generateCertificate(siteList);
  }

  /// Generates a local 2-tier PKI:
  /// 1. Devlika Local Root CA (installed to Windows Trusted Root store)
  /// 2. Server Leaf Certificate signed by Root CA with full Subject Alternative Names (SAN),
  ///    SHA-256 signature, and 397-day validity (Chromium/Apple requirement compliant).
  /// 3. Full-chain bundle (server.crt + ca.crt).
  Future<bool> generateCertificate(List<SiteModel> sites) async {
    final config = ConfigService.instance;
    final sslDir = Directory(config.sslDir);
    if (!sslDir.existsSync()) {
      sslDir.createSync(recursive: true);
    }

    final openssl = config.opensslExe;

    try {
      // 1. Generate Devlika Local Root CA if not present
      final caCertFile = File(caCertPath);
      final caKeyFile = File(caKeyPath);
      final caCnfPath = p.join(sslDir.path, 'ca.cnf');

      if (!caCertFile.existsSync() || !caKeyFile.existsSync()) {
        final caCnfContent = '''
[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
x509_extensions     = v3_ca
prompt              = no

[ req_distinguished_name ]
C                   = ID
ST                  = Riau
L                   = Pekanbaru
O                   = Devlika Local Development
OU                  = Security CA
CN                  = Devlika Local Root CA

[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical, CA:true
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign
''';
        File(caCnfPath).writeAsStringSync(caCnfContent);

        await Process.run(openssl, [
          'req',
          '-x509',
          '-nodes',
          '-sha256',
          '-days',
          '3650',
          '-newkey',
          'rsa:2048',
          '-keyout',
          caKeyPath,
          '-out',
          caCertPath,
          '-config',
          caCnfPath,
        ]);
      }

      // 2. Prepare SAN list for Server Leaf Certificate
      final dnsNames = buildRequiredDomains(sites);

      final altNamesBuffer = StringBuffer();
      int dnsIndex = 1;
      for (final d in dnsNames) {
        altNamesBuffer.writeln('DNS.$dnsIndex = $d');
        dnsIndex++;
      }
      altNamesBuffer.writeln('IP.1 = 127.0.0.1');
      altNamesBuffer.writeln('IP.2 = ::1');

      final serverCnfPath = p.join(sslDir.path, 'server.cnf');
      final serverCsrPath = p.join(sslDir.path, 'server.csr');

      final serverCnfContent = '''
[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
req_extensions      = req_ext
prompt              = no

[ req_distinguished_name ]
C                   = ID
ST                  = Riau
L                   = Pekanbaru
O                   = Devlika Local Development
OU                  = Web Server
CN                  = Devlika Local Server

[ req_ext ]
basicConstraints     = CA:FALSE
keyUsage             = digitalSignature, keyEncipherment
extendedKeyUsage     = serverAuth, clientAuth
subjectAltName       = @alt_names

[ server_ext ]
basicConstraints     = CA:FALSE
keyUsage             = digitalSignature, keyEncipherment
extendedKeyUsage     = serverAuth, clientAuth
subjectAltName       = @alt_names
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[ alt_names ]
${altNamesBuffer.toString().trim()}
''';
      File(serverCnfPath).writeAsStringSync(serverCnfContent);

      // Generate Server Key & CSR
      final csrRes = await Process.run(openssl, [
        'req',
        '-new',
        '-nodes',
        '-sha256',
        '-newkey',
        'rsa:2048',
        '-keyout',
        keyPath,
        '-out',
        serverCsrPath,
        '-config',
        serverCnfPath,
      ]);
      if (csrRes.exitCode != 0) {
        // ignore: avoid_print
        print('OpenSSL req error (code ${csrRes.exitCode}): ${csrRes.stderr}');
      }

      // Sign Server CSR with Devlika Root CA
      // Uses 397 days validity: strictly conforms to Chromium/Safari 398-day maximum policy
      final signRes = await Process.run(openssl, [
        'x509',
        '-req',
        '-in',
        serverCsrPath,
        '-CA',
        caCertPath,
        '-CAkey',
        caKeyPath,
        '-CAcreateserial',
        '-out',
        certPath,
        '-days',
        '397',
        '-sha256',
        '-extfile',
        serverCnfPath,
        '-extensions',
        'server_ext',
      ]);
      if (signRes.exitCode != 0) {
        // ignore: avoid_print
        print('OpenSSL x509 sign error (code ${signRes.exitCode}): ${signRes.stderr}');
      }

      // Generate fullchain.crt (Server Cert + Root CA) for optimal TLS client trust
      if (File(certPath).existsSync() && File(caCertPath).existsSync()) {
        final serverCert = File(certPath).readAsStringSync().trim();
        final caCert = File(caCertPath).readAsStringSync().trim();
        File(fullChainCertPath).writeAsStringSync('$serverCert\n\n$caCert\n');
      }

      // Record covered domains to domains.json for incremental SAN detection
      File(domainsJsonPath).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(dnsNames.toList()..sort()),
      );

      // Generate Helper Batch script in SSL directory for manual installation if needed
      final batFile = File(p.join(sslDir.path, 'install_ssl_certificate.bat'));
      batFile.writeAsStringSync('''@echo off
echo ========================================================
echo   DevlikaStack - Registrasi Root CA SSL ke Windows Store
echo ========================================================
echo.
echo Mendaftarkan Devlika Root CA ke Windows Trusted Root Store...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Import-Certificate -FilePath '%~dp0ca.crt' -CertStoreLocation 'Cert:\\CurrentUser\\Root'; Start-Process certutil -Verb RunAs -ArgumentList @('-addstore', '-f', 'ROOT', '%~dp0ca.crt') -Wait"
echo.
echo Registrasi selesai. Silakan restart browser untuk memperbarui status sertifikat.
echo Seluruh virtual host HTTPS (port 443) kini berstatus terverifikasi (trusted).
pause
''');

      return hasCertificate;
    } catch (_) {
      return hasCertificate;
    }
  }

  /// Checks if Devlika Local Root CA is currently installed and trusted in Windows Certificate Store.
  Future<bool> isCertificateTrusted() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        '& { \$found = Get-ChildItem -Path Cert:\\CurrentUser\\Root, Cert:\\LocalMachine\\Root -ErrorAction SilentlyContinue | Where-Object { \$_.Subject -like "*Devlika*" }; if (\$found) { exit 0 } else { exit 1 } }',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Installs Devlika Root CA into Windows Trusted Root Certification Authorities store:
  /// 1. CurrentUser\\Root via .NET X509Store (instant, silent, 100% reliable)
  /// 2. LocalMachine\\Root via certutil RunAs (elevated machine-wide trust)
  Future<bool> installCertificateToWindowsStore() async {
    final caFile = File(caCertPath);
    if (!caFile.existsSync()) {
      final ok = await ensureCertificate(force: true);
      if (!ok) return false;
    }

    try {
      final caNormPath = p.normalize(caFile.absolute.path).replaceAll("'", "''");

      // 1. CurrentUser\Root: Installs root certificate silently and immediately via .NET
      final userStoreScript = "& { "
          "\$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2('$caNormPath'); "
          "\$store = New-Object System.Security.Cryptography.X509Certificates.X509Store('Root', 'CurrentUser'); "
          "\$store.Open('ReadWrite'); "
          "\$store.Add(\$cert); "
          "\$store.Close(); "
          "}";

      await Process.run('powershell', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        userStoreScript,
      ]);

      // 2. Also register to LocalMachine\Root if possible via certutil
      try {
        await Process.run('powershell', [
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          "Start-Process certutil -ArgumentList @('-addstore', '-f', 'ROOT', '$caNormPath') -Verb RunAs",
        ]);
      } catch (_) {}

      return await isCertificateTrusted();
    } catch (_) {
      return await isCertificateTrusted();
    }
  }
}

