import 'dart:io';

class PortStatus {
  final int port;
  final bool isFree;
  final int? pid;
  final String? processName;
  final String? friendlyName;

  const PortStatus({
    required this.port,
    required this.isFree,
    this.pid,
    this.processName,
    this.friendlyName,
  });

  String get description {
    if (isFree) return 'Tersedia';
    if (friendlyName != null && friendlyName!.isNotEmpty) {
      return 'Digunakan oleh $friendlyName (PID: ${pid ?? "?"})';
    }
    if (processName != null && processName!.isNotEmpty) {
      return 'Digunakan oleh $processName (PID: ${pid ?? "?"})';
    }
    return 'Sedang digunakan aplikasi lain';
  }
}

class PortCheckerService {
  static final PortCheckerService instance = PortCheckerService._();
  PortCheckerService._();

  Future<PortStatus> checkPort(int port) async {
    // 1. Fast socket bind attempt
    ServerSocket? socket;
    try {
      socket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await socket.close();
      return PortStatus(port: port, isFree: true);
    } catch (_) {
      // Port is occupied
    }

    // 2. Identify process on Windows
    if (Platform.isWindows) {
      try {
        final netstatRes = await Process.run('netstat', ['-ano', '-p', 'tcp']);
        if (netstatRes.exitCode == 0) {
          final lines = (netstatRes.stdout as String).split('\n');
          final pattern = RegExp(':$port\\s+.*?LISTENING\\s+(\\d+)', caseSensitive: false);
          int? foundPid;
          for (final line in lines) {
            final match = pattern.firstMatch(line);
            if (match != null) {
              foundPid = int.tryParse(match.group(1) ?? '');
              if (foundPid != null) break;
            }
          }

          if (foundPid != null) {
            String? procName;
            if (foundPid == 4) {
              procName = 'System';
            } else {
              final tasklistRes = await Process.run('tasklist', ['/FI', 'PID eq $foundPid', '/FO', 'CSV', '/NH']);
              if (tasklistRes.exitCode == 0) {
                final out = (tasklistRes.stdout as String).trim();
                if (out.isNotEmpty && !out.contains('INFO:')) {
                  // CSV format: "image.exe","pid","session","num","mem"
                  final parts = out.split('","');
                  if (parts.isNotEmpty) {
                    procName = parts[0].replaceAll('"', '').trim();
                  }
                }
              }
            }

            final friendly = _getFriendlyProcessName(procName, foundPid);
            return PortStatus(
              port: port,
              isFree: false,
              pid: foundPid,
              processName: procName,
              friendlyName: friendly,
            );
          }
        }
      } catch (_) {}
    }

    return PortStatus(port: port, isFree: false);
  }

  String _getFriendlyProcessName(String? procName, int pid) {
    if (pid == 4 || procName?.toLowerCase() == 'system') {
      return 'Windows System / IIS';
    }
    final lower = procName?.toLowerCase() ?? '';
    if (lower.contains('httpd')) return 'Apache / XAMPP';
    if (lower.contains('mysqld') || lower.contains('mariadbd')) return 'MySQL / XAMPP';
    if (lower.contains('nginx')) return 'Nginx Web Server';
    if (lower.contains('skype')) return 'Skype';
    if (lower.contains('node')) return 'Node.js';
    if (lower.contains('python')) return 'Python Server';
    if (lower.contains('devlika')) return 'DevlikaStack';
    return procName ?? 'Aplikasi Lain';
  }

  Future<int> suggestAlternativeHttpPort({int start = 8080}) async {
    final candidates = [8080, 8000, 8888, 8088, 8800];
    for (final p in candidates) {
      final status = await checkPort(p);
      if (status.isFree) return p;
    }
    return start;
  }

  Future<int> suggestAlternativeMariaDbPort({int start = 3307}) async {
    final candidates = [3307, 3308, 3309, 3366];
    for (final p in candidates) {
      final status = await checkPort(p);
      if (status.isFree) return p;
    }
    return start;
  }
}
