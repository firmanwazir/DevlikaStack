import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'config_service.dart';
import 'mariadb_manager.dart';
import 'server_controller.dart';

class DbImporterService extends ChangeNotifier {
  static final DbImporterService instance = DbImporterService._();
  DbImporterService._();

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  double _progress = 0.0;
  double get progress => _progress;

  int _bytesProcessed = 0;
  int get bytesProcessed => _bytesProcessed;

  int _totalBytes = 0;
  int get totalBytes => _totalBytes;

  double _speedMBps = 0.0;
  double get speedMBps => _speedMBps;

  String _etaText = '';
  String get etaText => _etaText;

  String _elapsedText = '00:00';
  String get elapsedText => _elapsedText;

  String _statusMessage = '';
  String get statusMessage => _statusMessage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _lastCompletedInfo;
  String? get lastCompletedInfo => _lastCompletedInfo;

  String? _currentFilePath;
  String? get currentFilePath => _currentFilePath;

  String? _currentDatabase;
  String? get currentDatabase => _currentDatabase;

  Process? _activeProcess;
  bool _isCancelled = false;

  /// Fetch list of existing user databases from MariaDB
  Future<List<String>> getDatabases() async {
    final config = ConfigService.instance;
    final clientExe = config.mariaDbClientExe;

    if (!File(clientExe).existsSync() || !MariaDbManager.instance.isRunning) {
      return [];
    }

    try {
      final res = await Process.run(
        clientExe,
        ['-u', 'root', '--host=127.0.0.1', '--port=3306', '-N', '-s', '-e', 'SHOW DATABASES;'],
      );

      if (res.exitCode == 0) {
        final lines = res.stdout.toString().split(RegExp(r'\r?\n'));
        final ignored = {'information_schema', 'performance_schema', 'mysql', 'sys'};
        return lines
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty && !ignored.contains(l.toLowerCase()))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Create a new database with utf8mb4 collation
  Future<bool> createDatabase(String dbName) async {
    final clean = dbName.trim();
    if (clean.isEmpty || !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
      _errorMessage = 'Nama database hanya boleh berupa huruf, angka, dan underscore.';
      notifyListeners();
      return false;
    }

    final config = ConfigService.instance;
    final clientExe = config.mariaDbClientExe;

    if (!File(clientExe).existsSync()) {
      _errorMessage = 'Client MariaDB (mysql.exe) tidak ditemukan.';
      notifyListeners();
      return false;
    }

    try {
      final sql = 'CREATE DATABASE IF NOT EXISTS `$clean` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;';
      final res = await Process.run(
        clientExe,
        ['-u', 'root', '--host=127.0.0.1', '--port=3306', '-e', sql],
      );

      if (res.exitCode == 0) {
        ServerController.instance.logsNotifier.addLog('[DB Importer] Database `$clean` siap digunakan.');
        return true;
      } else {
        _errorMessage = 'Gagal membuat database: ${res.stderr}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error koneksi MariaDB: $e';
      notifyListeners();
      return false;
    }
  }

  /// Start Turbo Import Pipeline directly streaming file to MariaDB CLI
  Future<bool> startImport({
    required String sqlFilePath,
    required String targetDatabase,
    bool createDbIfNotExists = true,
  }) async {
    if (_isImporting) return false;

    final file = File(sqlFilePath);
    if (!file.existsSync()) {
      _errorMessage = 'File SQL tidak ditemukan pada lokasi yang dipilih.';
      notifyListeners();
      return false;
    }

    final config = ConfigService.instance;
    final clientExe = config.mariaDbClientExe;
    if (!File(clientExe).existsSync()) {
      _errorMessage = 'Binary MariaDB (mysql.exe) belum terpasang di folder bin/mariadb/bin.';
      notifyListeners();
      return false;
    }

    // Ensure MariaDB is running
    if (!MariaDbManager.instance.isRunning) {
      _statusMessage = 'Menjalankan server MariaDB...';
      notifyListeners();
      final started = await MariaDbManager.instance.start();
      if (!started) {
        _errorMessage = 'Gagal mengaktifkan MariaDB. Pastikan port 3306 tidak terpakai.';
        notifyListeners();
        return false;
      }
    }

    final cleanDb = targetDatabase.trim();
    if (cleanDb.isEmpty || !RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanDb)) {
      _errorMessage = 'Nama database tujuan tidak valid (hanya huruf, angka, dan underscore).';
      notifyListeners();
      return false;
    }

    if (createDbIfNotExists) {
      final created = await createDatabase(cleanDb);
      if (!created) return false;
    }

    _isImporting = true;
    _isCancelled = false;
    _progress = 0.0;
    _bytesProcessed = 0;
    _totalBytes = file.lengthSync();
    _currentFilePath = sqlFilePath;
    _currentDatabase = cleanDb;
    _speedMBps = 0.0;
    _etaText = 'Mempersiapkan...';
    _elapsedText = '00:00';
    _errorMessage = null;
    _lastCompletedInfo = null;
    _statusMessage = 'Menghubungkan ke MariaDB CLI Pipeline...';
    notifyListeners();

    final fileName = p.basename(sqlFilePath);
    final sizeFormatted = formatBytes(_totalBytes);
    ServerController.instance.logsNotifier.addLog(
      '[DB Importer] Memulai Turbo Import: $fileName ($sizeFormatted) ke database `$cleanDb`...',
    );

    final stopwatch = Stopwatch()..start();
    final processArgs = [
      '-u', 'root',
      '--host=127.0.0.1',
      '--port=3306',
      '--default-character-set=utf8mb4',
      '--max_allowed_packet=1024M',
      '--net_buffer_length=1048576',
      '--binary-mode',
      '-q',
      cleanDb,
    ];

    final stderrBuffer = StringBuffer();
    try {
      final process = await Process.start(
        clientExe,
        processArgs,
        runInShell: false,
      );
      _activeProcess = process;

      // Continuously drain stdout to prevent OS pipe deadlock on verbose dumps / queries
      process.stdout.listen((_) {}, onError: (_) {});

      // Cap stderr buffer at 64 KB to prevent memory exhaustion from verbose warnings
      // and safely handle malformed non-UTF8 OEM console strings
      process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen(
        (data) {
          if (stderrBuffer.length < 64 * 1024) {
            stderrBuffer.write(data);
          }
        },
        onError: (_) {},
      );

      // 1. Inject Turbo Pre-Import Session Flags (disable checks, safe commit buffering, and extended timeouts)
      final turboHeader = '''
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;
SET SQL_LOG_BIN = 0;
SET GLOBAL innodb_flush_log_at_trx_commit = 2;
SET SESSION sort_buffer_size = 67108864;
SET SESSION bulk_insert_buffer_size = 67108864;
SET SESSION net_read_timeout = 3600;
SET SESSION net_write_timeout = 3600;
SET SESSION wait_timeout = 28800;
SET SESSION interactive_timeout = 28800;
''';
      process.stdin.add(utf8.encode(turboHeader));

      // 2. Stream SQL file in 1 MB sequential clusters directly to stdin
      _statusMessage = 'Mengalirkan query transaksi turbo...';
      final fileStream = file.openRead();
      int lastNotificationTime = 0;
      int bytesInWindow = 0;
      int lastWindowTime = stopwatch.elapsedMilliseconds;
      int bytesBufferedSinceFlush = 0;
      const int hddFlushThreshold = 1024 * 1024; // 1 MB batches reduce mechanical HDD seek-thrashing by 16x

      await for (final chunk in fileStream) {
        if (_isCancelled) {
          try {
            process.kill();
          } catch (_) {}
          _statusMessage = 'Proses import dibatalkan oleh pengguna.';
          _errorMessage = 'Import dibatalkan oleh pengguna.';
          notifyListeners();
          return false;
        }

        try {
          process.stdin.add(chunk);
          bytesBufferedSinceFlush += chunk.length;

          // Flush every 1 MB or at EOF.
          // On HDD, 1 MB sequential reading prevents physical head thrashing between file reads and DB writes.
          if (bytesBufferedSinceFlush >= hddFlushThreshold || _bytesProcessed + chunk.length >= _totalBytes) {
            await process.stdin.flush();
            bytesBufferedSinceFlush = 0;
          }
        } catch (_) {
          // Process may have exited early with an error
          break;
        }

        _bytesProcessed += chunk.length;
        bytesInWindow += chunk.length;

        final nowMs = stopwatch.elapsedMilliseconds;
        // Calculate smoothed rolling speed (EMA) to handle HDD dirty page checkpointing
        final windowDelta = nowMs - lastWindowTime;
        if (windowDelta >= 800) {
          final instantSpeed = (bytesInWindow / (1024 * 1024)) / (windowDelta / 1000.0);
          _speedMBps = _speedMBps == 0.0 ? instantSpeed : (_speedMBps * 0.7 + instantSpeed * 0.3);
          bytesInWindow = 0;
          lastWindowTime = nowMs;

          // Calculate ETA
          final remainingBytes = _totalBytes - _bytesProcessed;
          if (_speedMBps > 0.05) {
            final secondsLeft = (remainingBytes / (1024 * 1024)) / _speedMBps;
            _etaText = _formatDuration(secondsLeft.toInt());
          } else {
            _etaText = 'Menulis ke disk...';
          }
        }

        // Throttle UI notification to ~250ms
        if (nowMs - lastNotificationTime >= 250 || _bytesProcessed == _totalBytes) {
          lastNotificationTime = nowMs;
          _progress = _totalBytes > 0 ? (_bytesProcessed / _totalBytes).clamp(0.0, 1.0) : 0.0;
          _elapsedText = _formatDuration((nowMs / 1000).toInt());
          notifyListeners();
        }
      }

      if (_isCancelled) {
        _statusMessage = 'Proses import dibatalkan oleh pengguna.';
        _errorMessage = 'Import dibatalkan oleh pengguna.';
        notifyListeners();
        return false;
      }

      if (_bytesProcessed == _totalBytes) {
        // 3. Inject restore checks only if stream finished 100%
        _statusMessage = 'Mengaktifkan kembali verifikasi integritas indeks...';
        notifyListeners();

        final turboFooter = '''
SET UNIQUE_CHECKS = 1;
SET FOREIGN_KEY_CHECKS = 1;
''';
        try {
          process.stdin.add(utf8.encode(turboFooter));
          await process.stdin.flush();
          await process.stdin.close();
        } catch (_) {}
      } else {
        try {
          await process.stdin.close();
        } catch (_) {}
      }

      final exitCode = await process.exitCode;
      stopwatch.stop();

      if (exitCode == 0) {
        _progress = 1.0;
        _speedMBps = 0.0;
        _etaText = 'Selesai';
        final durationStr = _formatDuration((stopwatch.elapsedMilliseconds / 1000).toInt());
        _statusMessage = 'Import database berhasil diselesaikan!';
        _lastCompletedInfo = 'Database `$cleanDb` ($sizeFormatted) berhasil diimpor dalam $durationStr.';
        ServerController.instance.logsNotifier.addLog(
          '[DB Importer] Sukses! File $fileName berhasil diimpor ke `$cleanDb` dalam $durationStr.',
        );
        notifyListeners();
        return true;
      } else {
        final err = stderrBuffer.toString().trim();
        _errorMessage = err.isNotEmpty ? err : 'Proses MariaDB keluar dengan kode error $exitCode.';
        ServerController.instance.logsNotifier.addLog('[DB Importer Error] Gagal: $_errorMessage');
        notifyListeners();
        return false;
      }
    } catch (e) {
      final err = stderrBuffer.toString().trim();
      _errorMessage = err.isNotEmpty ? err : 'Terjadi kesalahan sistem: $e';
      ServerController.instance.logsNotifier.addLog('[DB Importer Error] $_errorMessage');
      notifyListeners();
      return false;
    } finally {
      _isImporting = false;
      if (_activeProcess != null) {
        try {
          _activeProcess?.kill();
        } catch (_) {}
        _activeProcess = null;
      }
      notifyListeners();
    }
  }

  /// Cancel active import process immediately
  void cancelImport() {
    if (_isImporting && _activeProcess != null) {
      _isCancelled = true;
      try {
        _activeProcess?.kill();
      } catch (_) {}
      _statusMessage = 'Membatalkan import...';
      _errorMessage = 'Import dibatalkan oleh pengguna.';
      ServerController.instance.logsNotifier.addLog('[DB Importer] Pembatalan import diminta oleh pengguna.');
      notifyListeners();
    }
  }

  void clearStatus() {
    _statusMessage = '';
    _errorMessage = null;
    _lastCompletedInfo = null;
    _currentFilePath = null;
    _currentDatabase = null;
    _progress = 0.0;
    notifyListeners();
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatDuration(int seconds) {
    if (seconds < 0) return '00:00';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final h = m ~/ 60;
    if (h > 0) {
      final remM = m % 60;
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
