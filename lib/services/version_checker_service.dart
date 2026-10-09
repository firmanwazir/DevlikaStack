import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'config_service.dart';
import 'php_manager.dart';

class MariaDbVersionInfo {
  final String installedVersion;
  final String latestStable;
  final bool hasUpdate;
  final String architecture;
  final String status;
  final DateTime lastChecked;

  const MariaDbVersionInfo({
    required this.installedVersion,
    required this.latestStable,
    required this.hasUpdate,
    required this.architecture,
    required this.status,
    required this.lastChecked,
  });
}

class PhpUpdateInfo {
  final String versionKey;
  final String name;
  final String? installedVersion;
  final String latestVersion;
  final bool isInstalled;
  final bool hasUpdate;
  final String downloadUrl;

  const PhpUpdateInfo({
    required this.versionKey,
    required this.name,
    this.installedVersion,
    required this.latestVersion,
    required this.isInstalled,
    required this.hasUpdate,
    required this.downloadUrl,
  });
}

class VersionCheckerService extends ChangeNotifier {
  static final VersionCheckerService instance = VersionCheckerService._();
  VersionCheckerService._();

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  DateTime? _lastCheckedTime;
  DateTime? get lastCheckedTime => _lastCheckedTime;

  MariaDbVersionInfo? _mariaDbInfo;
  MariaDbVersionInfo? get mariaDbInfo => _mariaDbInfo;

  List<PhpUpdateInfo> _phpUpdates = [];
  List<PhpUpdateInfo> get phpUpdates => _phpUpdates;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Check all updates (PHP & MariaDB)
  Future<void> checkAll() async {
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        checkMariaDb(checkOnline: true),
        checkPhp(checkOnline: true),
      ]);
      _lastCheckedTime = DateTime.now();
    } catch (e) {
      _errorMessage = 'Gagal memeriksa pembaruan: $e';
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Detect & Check MariaDB Version
  Future<MariaDbVersionInfo> checkMariaDb({bool checkOnline = false}) async {
    final exe = ConfigService.instance.mariaDbExe;
    String installedVer = 'Belum Terpasang';
    String arch = 'x64';

    if (File(exe).existsSync()) {
      try {
        final res = await Process.run(exe, ['--version']);
        final out = res.stdout.toString().isNotEmpty ? res.stdout.toString() : res.stderr.toString();
        final match = RegExp(r'Ver\s+([0-9\.\-A-Za-z]+)').firstMatch(out);
        if (match != null) {
          installedVer = match.group(1)!;
        } else {
          installedVer = 'Versi Tidak Diketahui';
        }
        if (out.toLowerCase().contains('amd64') || out.toLowerCase().contains('win64')) {
          arch = 'Win64 (AMD64)';
        }
      } catch (_) {
        installedVer = 'Versi Tidak Diketahui';
      }
    }

    String latestStable = '12.0.2 (Portable)';
    bool hasUpdate = false;
    String status = 'Terkini & Stabil';

    // Query official MariaDB REST API only if checkOnline requested
    if (checkOnline) {
      try {
        final res = await http.get(
          Uri.parse('https://downloads.mariadb.org/rest-api/mariadb/'),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final majorReleases = data['major_releases'] as List?;
          if (majorReleases != null && majorReleases.isNotEmpty) {
            final stableList = majorReleases.where((r) => r['release_status'] == 'Stable').toList();
            if (stableList.isNotEmpty) {
              latestStable = '${stableList.first['release_name']} LTS';
            }
          }
        }
      } catch (_) {
        latestStable = '12.0.2 (Portable)';
      }
    }

    if (installedVer != 'Belum Terpasang') {
      if (installedVer.contains('12.0.2')) {
        status = 'Versi Terkini & Optimal';
        hasUpdate = false;
      } else {
        status = 'Versi Stabil Terpasang';
      }
    } else {
      status = 'Perlu Instalasi';
    }

    _mariaDbInfo = MariaDbVersionInfo(
      installedVersion: installedVer,
      latestStable: latestStable,
      hasUpdate: hasUpdate,
      architecture: arch,
      status: status,
      lastChecked: DateTime.now(),
    );

    notifyListeners();
    return _mariaDbInfo!;
  }

  /// Detect & Check PHP Versions
  Future<List<PhpUpdateInfo>> checkPhp({bool checkOnline = false}) async {
    final installedList = PhpManager.instance.getVersions();

    // Default latest known versions
    final Map<String, String> latestMap = {
      '7.4': '7.4.33',
      '8.1': '8.1.30',
      '8.2': '8.2.29',
      '8.3': '8.3.17',
      '8.4': '8.4.4',
    };

    final Map<String, String> downloadUrlMap = {
      '7.4': 'https://windows.php.net/downloads/releases/archives/php-7.4.33-nts-Win32-vc15-x64.zip',
      '8.1': 'https://windows.php.net/downloads/releases/archives/php-8.1.30-nts-Win32-vs16-x64.zip',
      '8.2': 'https://windows.php.net/downloads/releases/archives/php-8.2.29-nts-Win32-vs16-x64.zip',
      '8.3': 'https://windows.php.net/downloads/releases/php-8.3.17-nts-Win32-vs16-x64.zip',
      '8.4': 'https://windows.php.net/downloads/releases/php-8.4.4-nts-Win32-vs17-x64.zip',
    };

    // Query windows.php.net releases JSON only if checkOnline requested
    if (checkOnline) {
      try {
        final res = await http.get(
          Uri.parse('https://windows.php.net/downloads/releases/releases.json'),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          data.forEach((seriesKey, details) {
            if (details is Map && details.containsKey('version')) {
              final ver = details['version'].toString();
              latestMap[seriesKey] = ver;

              for (var buildKey in ['nts-vs17-x64', 'nts-vs16-x64']) {
                if (details.containsKey(buildKey) && details[buildKey] is Map) {
                  final zipInfo = details[buildKey]['zip'];
                  if (zipInfo is Map && zipInfo.containsKey('path')) {
                    downloadUrlMap[seriesKey] = 'https://windows.php.net/downloads/releases/${zipInfo['path']}';
                    break;
                  }
                }
              }
            }
          });
        }
      } catch (_) {}
    }

    final results = <PhpUpdateInfo>[];

    for (var ver in installedList) {
      final k = ver.versionKey;
      final name = ver.name;
      final isInstalled = ver.isInstalled;
      final installedVer = isInstalled ? ver.exactVersion : null;
      final latestVer = latestMap[k] ?? ver.exactVersion;

      bool hasUpdate = false;
      if (isInstalled && installedVer != null) {
        hasUpdate = _isNewerVersion(latestVer, installedVer);
      }

      results.add(PhpUpdateInfo(
        versionKey: k,
        name: name,
        installedVersion: installedVer,
        latestVersion: latestVer,
        isInstalled: isInstalled,
        hasUpdate: hasUpdate,
        downloadUrl: downloadUrlMap[k] ?? ver.downloadUrl,
      ));
    }

    _phpUpdates = results;
    notifyListeners();
    return results;
  }

  bool _isNewerVersion(String latest, String installed) {
    if (installed == 'Portable' || installed.isEmpty) return false;
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final iParts = installed.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final inst = i < iParts.length ? iParts[i] : 0;
        if (l > inst) return true;
        if (l < inst) return false;
      }
    } catch (_) {}
    return false;
  }
}
