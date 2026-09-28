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
  String get keyPath => ConfigService.instance.sslKeyFile;
  String get cnfPath => ConfigService.instance.sslCnfFile;

  bool get hasCertificate =>
      File(certPath).existsSync() &&
      File(keyPath).existsSync() &&
      File(caCertPath).existsSync();

  /// Ensures that Root CA and signed Leaf Certificate exist and cover all sites.
  Future<bool> ensureCertificate({List<SiteModel>? sites, bool force = false}) async {
    final config = ConfigService.instance;
    final sslDir = Directory(config.sslDir);
    if (!sslDir.existsSync()) {
      sslDir.createSync(recursive: true);
    }

    if (!force && hasCertificate) {
      return true;
    }

    final siteList = sites ?? config.loadSites();
    return await generateCertificate(siteList);
  }

  /// Generates a local 2-tier PKI:
  /// 1. Devlika Local Root CA (installed to Windows Trusted Root store)
  /// 2. Server Certificate signed by Root CA with full Subject Alternative Names (SAN)
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
      final dnsNames = <String>{
        'localhost',
        '*.local',
        '*.test',
        '*.univrab',
        '*.dev',
        '*.devel',
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
req_extensions      = v3_req
prompt              = no

[ req_distinguished_name ]
C                   = ID
ST                  = Riau
L                   = Pekanbaru
O                   = Devlika Local Development
CN                  = Devlika Local Server

[ v3_req ]
basicConstraints     = critical, CA:false
keyUsage             = critical, digitalSignature, keyEncipherment
extendedKeyUsage     = serverAuth, clientAuth
subjectAltName       = @alt_names

[ alt_names ]
${altNamesBuffer.toString().trim()}
''';
      File(serverCnfPath).writeAsStringSync(serverCnfContent);

      // Generate Server Key & CSR
      await Process.run(openssl, [
        'req',
        '-new',
        '-nodes',
        '-newkey',
        'rsa:2048',
        '-keyout',
        keyPath,
        '-out',
        serverCsrPath,
        '-config',
        serverCnfPath,
      ]);

      // Sign Server CSR with Devlika Root CA
      await Process.run(openssl, [
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
        '3650',
        '-extfile',
        serverCnfPath,
        '-extensions',
        'v3_req',
      ]);

      // Generate Helper Batch script in SSL directory
      final batFile = File(p.join(sslDir.path, 'install_ssl_certificate.bat'));
      batFile.writeAsStringSync('''@echo off
echo ========================================================
echo   Devlika Stack - Pasang Sertifikat SSL ke Windows Root
echo ========================================================
echo.
echo Mendaftarkan Devlika Root CA ke Windows Trusted Store...
powershell -NoProfile -Command "Start-Process certutil -Verb RunAs -ArgumentList '-addstore -f ROOT \\"%~dp0ca.crt\\"' -Wait"
echo.
echo Selesai! Silakan restart browser Chrome / Edge Anda.
echo Seluruh website lokal Devlika Stack (HTTPS port 443) sekarang akan SECURE (Gembok Hijau).
pause
''');

      return hasCertificate;
    } catch (_) {
      return hasCertificate;
    }
  }

  /// Installs Devlika Root CA into Windows Trusted Root Certification Authorities store
  /// using Windows UAC prompt.
  Future<bool> installCertificateToWindowsStore() async {
    final caFile = File(caCertPath);
    if (!caFile.existsSync()) {
      final ok = await ensureCertificate();
      if (!ok) return false;
    }

    try {
      final safeCaPath = caFile.path.replaceAll("'", "''");
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Process certutil -Verb RunAs -ArgumentList \'-addstore -f ROOT "$safeCaPath"\' -Wait',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
