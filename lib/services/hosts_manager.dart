import 'dart:io';
import 'package:path/path.dart' as p;

class HostsManager {
  static final HostsManager instance = HostsManager._();
  HostsManager._();

  static const String beginTag = '# BEGIN DEVLIKASTACK_ENTRIES';
  static const String endTag = '# END DEVLIKASTACK_ENTRIES';
  static const String legacyDevStackBeginTag = '# BEGIN DEVSTACK_ENTRIES';
  static const String legacyDevStackEndTag = '# END DEVSTACK_ENTRIES';
  static const String legacyBeginTag = '# BEGIN LOCAL_SERVER_APP';
  static const String legacyEndTag = '# END LOCAL_SERVER_APP';

  // Strict hostname validation (letters, numbers, hyphens, dots) to prevent Hosts file injection
  static final RegExp _validDomainRegex = RegExp(
    r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$',
  );

  String get hostsPath {
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    return p.join(systemRoot, r'System32\drivers\etc\hosts');
  }

  bool isDomainMapped(String domain) {
    final clean = domain.trim().toLowerCase();
    if (clean.isEmpty || clean == 'localhost' || !_validDomainRegex.hasMatch(clean)) return false;

    try {
      final file = File(hostsPath);
      if (!file.existsSync()) return false;
      final lines = file.readAsLinesSync();
      return lines.any((l) =>
          !l.trimLeft().startsWith('#') &&
          l.toLowerCase().contains(clean));
    } catch (_) {
      return false;
    }
  }

  Future<bool> syncDomains(List<String> domains) async {
    final cleanDomains = domains
        .map((d) => d.trim().toLowerCase())
        .where((d) =>
            d.isNotEmpty &&
            d != 'localhost' &&
            !d.contains('\n') &&
            !d.contains('\r') &&
            _validDomainRegex.hasMatch(d))
        .toSet()
        .toList();

    try {
      final file = File(hostsPath);
      if (!file.existsSync()) return false;

      final current = await file.readAsString();
      final updated = _buildUpdatedContent(current, cleanDomains);

      if (current.trim() == updated.trim()) {
        return true;
      }

      // Try direct write first
      try {
        await file.writeAsString(updated);
        return true;
      } catch (_) {
        // Fallback to elevated PowerShell
        return await _elevatedWriteHosts(updated);
      }
    } catch (_) {
      return false;
    }
  }

  String _buildUpdatedContent(String current, List<String> domains) {
    final lines = current.split(RegExp(r'\r?\n'));
    // Remove legacy tags if present
    void removeRange(String bTag, String eTag) {
      final s = lines.indexWhere((l) => l.trim().toLowerCase() == bTag.toLowerCase());
      final e = lines.indexWhere((l) => l.trim().toLowerCase() == eTag.toLowerCase());
      if (s >= 0 && e >= s) {
        lines.removeRange(s, e + 1);
      }
    }

    removeRange(legacyBeginTag, legacyEndTag);
    removeRange(legacyDevStackBeginTag, legacyDevStackEndTag);
    removeRange(beginTag, endTag);

    final buffer = StringBuffer();
    for (var l in lines) {
      buffer.writeln(l);
    }

    if (domains.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(beginTag);
      buffer.writeln('127.0.0.1  localhost');
      buffer.writeln('::1        localhost');
      for (var d in domains) {
        buffer.writeln('127.0.0.1  $d');
        buffer.writeln('::1        $d');
      }
      buffer.writeln(endTag);
    }

    return '${buffer.toString().trimRight()}\n';
  }

  Future<bool> _elevatedWriteHosts(String content) async {
    final tempFile = File(p.join(
        Directory.systemTemp.path, 'hosts_tmp_${DateTime.now().millisecondsSinceEpoch}.txt'));
    try {
      await tempFile.writeAsString(content);

      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-WindowStyle',
          'Hidden',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          'Start-Process powershell -WindowStyle Hidden -Verb RunAs -Wait -ArgumentList \'-NoProfile -WindowStyle Hidden -Command Copy-Item -Path "${tempFile.path}" -Destination "$hostsPath" -Force\''
        ],
        runInShell: false,
      );

      return result.exitCode == 0;
    } catch (_) {
      return false;
    } finally {
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
  }
}
