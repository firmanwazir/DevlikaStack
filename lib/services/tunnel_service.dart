import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'config_service.dart';

class TunnelService extends ChangeNotifier {
  static final TunnelService instance = TunnelService._();
  TunnelService._();

  Process? _process;
  bool _isRunning = false;
  bool _isStarting = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  String? _activeDomain;
  int? _activePort;
  String? _publicUrl;
  String? _lastError;
  DateTime? _startedAt;

  // Auto-reconnect state
  bool _autoReconnectEnabled = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  Timer? _healthCheckTimer;

  // Stream listener subscriptions for cleanup
  StreamSubscription? _stdoutSub;
  StreamSubscription? _stderrSub;

  bool get isRunning => _isRunning;
  bool get isStarting => _isStarting;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;

  String? get activeDomain => _activeDomain;
  int? get activePort => _activePort;
  String? get publicUrl => _publicUrl;
  String? get lastError => _lastError;
  DateTime? get startedAt => _startedAt;
  bool get autoReconnectEnabled => _autoReconnectEnabled;
  int get reconnectAttempts => _reconnectAttempts;

  bool get isInstalled => ConfigService.instance.isCloudflaredInstalled;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  void setAutoReconnect(bool enabled) {
    _autoReconnectEnabled = enabled;
    if (!enabled) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    notifyListeners();
  }

  Future<bool> downloadCloudflared({Function(String, double)? onProgress}) async {
    if (isInstalled) return true;
    if (_isDownloading) return false; // Prevent double download

    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadStatus = 'Mempersiapkan unduhan Cloudflare Tunnel...';
    notifyListeners();

    final config = ConfigService.instance;
    config.ensureDirectories();
    final exePath = config.cloudflaredExe;
    final tempPath = '$exePath.tmp';

    const downloadUrl =
        'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe';

    http.Client? client;
    IOSink? sink;

    try {
      client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'DevlikaStack-Downloader';
      // Follow redirects (GitHub redirects to S3/CDN)
      request.followRedirects = true;
      request.maxRedirects = 5;
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Gagal mengunduh: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 55000000;
      var receivedBytes = 0;
      final file = File(tempPath);
      file.parent.createSync(recursive: true);
      sink = file.openWrite();

      // Throttle notifyListeners to max 10 updates/sec to prevent UI lag
      DateTime lastNotify = DateTime.now();
      const notifyInterval = Duration(milliseconds: 100);

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        _downloadProgress = (receivedBytes / totalBytes).clamp(0.0, 1.0);

        final now = DateTime.now();
        if (now.difference(lastNotify) >= notifyInterval || receivedBytes >= totalBytes) {
          final mb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
          final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
          _downloadStatus = 'Mengunduh cloudflared ($mb / $totalMb MB)...';
          onProgress?.call(_downloadStatus, _downloadProgress);
          lastNotify = now;
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;
      client.close();
      client = null;

      // Atomic swap: delete old, rename new
      if (File(exePath).existsSync()) {
        try { File(exePath).deleteSync(); } catch (_) {}
      }
      file.renameSync(exePath);

      // Verify binary is valid (at least 1MB)
      final finalSize = File(exePath).lengthSync();
      if (finalSize < 1024 * 1024) {
        File(exePath).deleteSync();
        throw Exception('Binary terlalu kecil ($finalSize bytes), file mungkin rusak.');
      }

      _isDownloading = false;
      _downloadProgress = 1.0;
      _downloadStatus = 'Cloudflare Tunnel berhasil dipasang!';
      _logController.add('[Cloudflare Tunnel] cloudflared.exe berhasil diunduh (${(finalSize / 1024 / 1024).toStringAsFixed(1)} MB).');
      notifyListeners();
      return true;
    } catch (e) {
      _isDownloading = false;
      _downloadStatus = 'Gagal mengunduh: $e';
      _logController.add('[Cloudflare Tunnel] ERROR: Gagal mengunduh cloudflared: $e');
      notifyListeners();

      // Clean up partial downloads
      try { sink?.close(); } catch (_) {}
      try { client?.close(); } catch (_) {}
      try { if (File(tempPath).existsSync()) File(tempPath).deleteSync(); } catch (_) {}

      return false;
    }
  }

  Future<bool> startTunnel({required String domain, int localPort = 80}) async {
    if (_isStarting) return false; // Prevent double-start race condition

    if (!isInstalled) {
      final ok = await downloadCloudflared();
      if (!ok) return false;
    }

    if (_isRunning) {
      await stopTunnel();
      // Small delay to ensure port/process is fully released
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isStarting = true;
    _lastError = null;
    _publicUrl = null;
    _activeDomain = domain;
    _activePort = localPort;
    notifyListeners();

    final config = ConfigService.instance;
    final exe = config.cloudflaredExe;

    try {
      final args = [
        'tunnel',
        '--url', 'http://127.0.0.1:$localPort',
        if (domain.isNotEmpty && domain != 'localhost') ...['--http-host-header', domain],
        '--no-autoupdate',
        '--metrics', '127.0.0.1:0', // Bind metrics to random port, avoids port conflicts
      ];

      _logController.add('[Cloudflare Tunnel] Menjalankan: cloudflared ${args.join(' ')}');

      _process = await Process.start(
        exe,
        args,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      final completer = Completer<String?>();

      void handleLog(String line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return;

        _logController.add('[Cloudflare Tunnel] $trimmed');

        // Regex for Cloudflare Quick Tunnel URL: https://xxx.trycloudflare.com
        final reg = RegExp(r'https://[a-zA-Z0-9-]+\.trycloudflare\.com');
        final match = reg.firstMatch(line);
        if (match != null && !completer.isCompleted) {
          completer.complete(match.group(0));
        }
      }

      // Cancel previous subscriptions if any (safety)
      await _stdoutSub?.cancel();
      await _stderrSub?.cancel();

      _stdoutSub = _process!.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((data) {
        for (var l in data.split('\n')) {
          handleLog(l);
        }
      });

      _stderrSub = _process!.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((data) {
        for (var l in data.split('\n')) {
          handleLog(l);
        }
      });

      // Handle process exit -> auto-reconnect
      _process!.exitCode.then((code) {
        _logController.add('[Cloudflare Tunnel] Proses keluar dengan kode: $code');
        final wasRunning = _isRunning;
        final savedDomain = _activeDomain;
        final savedPort = _activePort;

        _isRunning = false;
        _isStarting = false;
        _publicUrl = null;
        _process = null;

        // Cancel stream subscriptions
        _stdoutSub?.cancel();
        _stderrSub?.cancel();
        _stdoutSub = null;
        _stderrSub = null;

        // Stop health check
        _healthCheckTimer?.cancel();
        _healthCheckTimer = null;

        if (code != 0 && _lastError == null) {
          _lastError = 'Proses tunnel keluar dengan kode $code';
        }
        notifyListeners();

        // Auto-reconnect if the tunnel died unexpectedly while running
        if (wasRunning &&
            _autoReconnectEnabled &&
            _reconnectAttempts < _maxReconnectAttempts &&
            savedDomain != null &&
            savedPort != null) {
          _scheduleReconnect(savedDomain, savedPort);
        }
      });

      // Wait up to 25 seconds for Cloudflare edge to assign public URL
      // (increased from 20s to account for slow networks)
      final url = await completer.future.timeout(
        const Duration(seconds: 25),
        onTimeout: () => null,
      );

      if (url != null) {
        _publicUrl = url;
        _isRunning = true;
        _isStarting = false;
        _startedAt = DateTime.now();
        _reconnectAttempts = 0; // Reset on successful connection
        _logController.add('[Cloudflare Tunnel] ✅ Online preview aktif: $url -> $domain');
        _startHealthCheck();
        notifyListeners();
        return true;
      } else {
        _lastError = 'Timeout menunggu rute publik dari Cloudflare Edge (25s).';
        _isStarting = false;
        _logController.add('[Cloudflare Tunnel] ⚠ Timeout - tidak mendapat URL publik dalam 25 detik.');
        await _cleanupProcess();
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Gagal memulai tunnel: $e';
      _isStarting = false;
      _logController.add('[Cloudflare Tunnel] ERROR: $e');
      await _cleanupProcess();
      notifyListeners();
      return false;
    }
  }

  /// Schedule an auto-reconnect with exponential backoff
  void _scheduleReconnect(String domain, int port) {
    _reconnectAttempts++;
    // Exponential backoff: 3s, 6s, 12s, 24s, 48s
    final delaySec = 3 * (1 << (_reconnectAttempts - 1));
    final clampedDelay = delaySec.clamp(3, 60);

    _logController.add(
      '[Cloudflare Tunnel] 🔄 Auto-reconnect dalam ${clampedDelay}s '
      '(percobaan $_reconnectAttempts/$_maxReconnectAttempts)...',
    );
    notifyListeners();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: clampedDelay), () async {
      if (!_isRunning && !_isStarting && _autoReconnectEnabled) {
        _logController.add('[Cloudflare Tunnel] 🔄 Mencoba reconnect ke $domain...');
        final ok = await startTunnel(domain: domain, localPort: port);
        if (!ok && _reconnectAttempts < _maxReconnectAttempts) {
          // startTunnel's exitCode handler will schedule next attempt
        } else if (!ok) {
          _logController.add(
            '[Cloudflare Tunnel] ❌ Gagal reconnect setelah $_maxReconnectAttempts percobaan. '
            'Silakan coba manual.',
          );
          _lastError = 'Gagal reconnect setelah $_maxReconnectAttempts percobaan.';
          notifyListeners();
        }
      }
    });
  }

  /// Periodic health check: verify cloudflared process is still alive
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_process == null && _isRunning) {
        // Process vanished but state says running - fix the inconsistency
        _logController.add('[Cloudflare Tunnel] ⚠ Proses cloudflared hilang secara tidak terduga.');
        _isRunning = false;
        _publicUrl = null;
        notifyListeners();
      }
    });
  }

  /// Clean up process and stream subscriptions without resetting all state
  Future<void> _cleanupProcess() async {
    if (_process != null) {
      try { _process!.kill(); } catch (_) {}
      _process = null;
    }

    await _stdoutSub?.cancel();
    await _stderrSub?.cancel();
    _stdoutSub = null;
    _stderrSub = null;

    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/T', '/IM', 'cloudflared.exe'],
          runInShell: true,
        );
      } catch (_) {}
    }
  }

  Future<void> stopTunnel() async {
    // Cancel auto-reconnect
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;

    // Cancel health check
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    await _cleanupProcess();

    _isRunning = false;
    _isStarting = false;
    _publicUrl = null;
    _activeDomain = null;
    _activePort = null;
    _startedAt = null;
    _logController.add('[Cloudflare Tunnel] Tunnel dihentikan.');
    notifyListeners();
  }

  /// Dispose all resources when the app is shutting down
  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _healthCheckTimer?.cancel();
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    _cleanupProcess();
    _logController.close();
    super.dispose();
  }
}
