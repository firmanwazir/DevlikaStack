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
  final String? releaseDate;
  final bool isUpstreamDiscovered;

  const PhpUpdateInfo({
    required this.versionKey,
    required this.name,
    this.installedVersion,
    required this.latestVersion,
    required this.isInstalled,
    required this.hasUpdate,
    required this.downloadUrl,
    this.releaseDate,
    this.isUpstreamDiscovered = false,
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
  /// Detect & Check PHP Versions directly from official php.net live release feeds
  Future<List<PhpUpdateInfo>> checkPhp({bool checkOnline = false}) async {
    final installedList = PhpManager.instance.getVersions();

    // Map of seriesKey (e.g. "8.5") to exact version (e.g. "8.5.11")
    final Map<String, String> latestMap = {};
    final Map<String, String> downloadUrlMap = {};
    final Map<String, String> dateMap = {};

    // 1. Query live upstream release information from php.net official API if checkOnline requested
    if (checkOnline) {
      try {
        final endpoints = [
          'https://www.php.net/releases/index.php?json',
          'https://my.php.net/releases/index.php?json',
          'https://secure.php.net/releases/index.php?json',
        ];

        http.Response? res;
        for (final ep in endpoints) {
          try {
            final r = await http.get(
              Uri.parse(ep),
              headers: {'User-Agent': 'DevlikaStack-Updater/1.0'},
            ).timeout(const Duration(seconds: 10));
            if (r.statusCode == 200) {
              res = r;
              break;
            }
          } catch (_) {}
        }

        if (res != null && res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final versionsToQuery = <String>{};

          // Automatically extract all major releases (e.g. "8", "7", "9")
          for (final majorKey in data.keys) {
            final entry = data[majorKey];
            if (entry is Map<String, dynamic>) {
              // Ignore ancient museum versions (like PHP 3, 4, 5)
              if (entry['museum'] == true) continue;
              final majorNum = int.tryParse(majorKey) ?? 0;
              if (majorNum < 7) continue;

              // Extract supported minor versions array (e.g. ["8.2", "8.3", "8.4", "8.5"])
              final supp = entry['supported_versions'];
              if (supp is List) {
                for (final v in supp) {
                  final s = v.toString();
                  versionsToQuery.add(s);
                  // Ensure supported series is added immediately
                  if (!latestMap.containsKey(s)) {
                    latestMap[s] = s;
                  }
                }
              }
              // Extract current latest version of this major branch
              final cur = entry['version']?.toString();
              final curDate = entry['date']?.toString();
              if (cur != null && cur.isNotEmpty) {
                final parts = cur.split('.');
                if (parts.length >= 2) {
                  final series = '${parts[0]}.${parts[1]}';
                  latestMap[series] = cur;
                  if (curDate != null && curDate.isNotEmpty) {
                    dateMap[series] = curDate;
                  }
                }
              }
            }
          }

          // Concurrently fetch exact version for each supported series from official API
          await Future.wait(versionsToQuery.map((series) async {
            try {
              final vRes = await http.get(
                Uri.parse('https://www.php.net/releases/index.php?json&version=$series'),
                headers: {'User-Agent': 'DevlikaStack-Updater/1.0'},
              ).timeout(const Duration(seconds: 8));
              if (vRes.statusCode == 200) {
                final vData = jsonDecode(vRes.body) as Map<String, dynamic>;
                final exact = vData['version']?.toString();
                final vDate = vData['date']?.toString();
                if (exact != null && exact.isNotEmpty) {
                  latestMap[series] = exact;
                }
                if (vDate != null && vDate.isNotEmpty) {
                  dateMap[series] = vDate;
                }
              }
            } catch (_) {}
          }));
        } else {
          _errorMessage = 'Tidak dapat menghubungi server php.net. Periksa koneksi internet Anda.';
        }
      } catch (e) {
        _errorMessage = 'Gagal memeriksa php.net: $e';
      }

      // Also try windows.php.net if available to get exact binary zip paths
      try {
        final winRes = await http.get(
          Uri.parse('https://windows.php.net/downloads/releases/releases.json'),
          headers: {'User-Agent': 'DevlikaStack-Updater/1.0'},
        ).timeout(const Duration(seconds: 3));

        if (winRes.statusCode == 200) {
          final winData = jsonDecode(winRes.body) as Map<String, dynamic>;
          winData.forEach((seriesKey, details) {
            if (details is Map && details.containsKey('version')) {
              final ver = details['version'].toString();
              latestMap[seriesKey] = ver;

              for (var buildKey in ['nts-vs17-x64', 'nts-vs16-x64', 'nts-vc15-x64']) {
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

    // Automatically construct Windows binary download URLs for all discovered series
    for (final entry in latestMap.entries) {
      final series = entry.key;
      final exactVer = entry.value;
      if (!downloadUrlMap.containsKey(series)) {
        final parts = series.split('.');
        final major = int.tryParse(parts[0]) ?? 8;
        final minor = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        final vs = (major >= 8 && minor >= 4) ? 'vs17' : (major >= 8 ? 'vs16' : 'vc15');

        if (major <= 7) {
          downloadUrlMap[series] = 'https://windows.php.net/downloads/releases/archives/php-$exactVer-nts-Win32-$vs-x64.zip';
        } else {
          downloadUrlMap[series] = 'https://windows.php.net/downloads/releases/archives/php-$exactVer-nts-Win32-$vs-x64.zip';
        }
      }
    }

    final results = <PhpUpdateInfo>[];
    final installedMap = {for (var v in installedList) v.versionKey: v};

    // Combine all keys: installed versions + all upstream discovered versions!
    final allKeys = <String>{
      ...installedMap.keys,
      ...latestMap.keys,
    }.toList();

    // Sort versions in natural semver order (e.g. 7.4 < 8.1 < 8.2 < 8.3 < 8.4 < 8.5)
    allKeys.sort((a, b) {
      final aParts = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final bParts = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 2; i++) {
        final aVal = i < aParts.length ? aParts[i] : 0;
        final bVal = i < bParts.length ? bParts[i] : 0;
        if (aVal != bVal) return aVal.compareTo(bVal);
      }
      return a.compareTo(b);
    });

    for (final k in allKeys) {
      final installed = installedMap[k];
      final isInstalled = installed?.isInstalled ?? false;
      final installedVer = isInstalled ? installed?.exactVersion : null;
      final latestVer = latestMap[k] ?? (installedVer ?? k);
      final downloadUrl = downloadUrlMap[k] ?? (installed?.downloadUrl ?? '');
      final isUpstream = latestMap.containsKey(k);

      bool hasUpdate = false;
      if (isInstalled && installedVer != null) {
        hasUpdate = _isNewerVersion(latestVer, installedVer);
      } else if (!isInstalled) {
        hasUpdate = true; // Not installed yet -> available for install
      }

      final name = installed?.name ?? 'PHP $k';

      results.add(PhpUpdateInfo(
        versionKey: k,
        name: name,
        installedVersion: installedVer,
        latestVersion: latestVer,
        isInstalled: isInstalled,
        hasUpdate: hasUpdate,
        downloadUrl: downloadUrl,
        releaseDate: dateMap[k],
        isUpstreamDiscovered: isUpstream,
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
