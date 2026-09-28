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

  bool get isInstalled => ConfigService.instance.isCloudflaredInstalled;

  final _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  Future<bool> downloadCloudflared({Function(String, double)? onProgress}) async {
    if (isInstalled) return true;
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

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      request.headers['User-Agent'] = 'DevlikaStack-Downloader';
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Gagal mengunduh: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 55000000;
      var receivedBytes = 0;
      final file = File(tempPath);
      file.parent.createSync(recursive: true);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        _downloadProgress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
        final mb = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
        final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
        _downloadStatus = 'Mengunduh cloudflared ($mb / $totalMb MB)...';
        onProgress?.call(_downloadStatus, _downloadProgress);
        notifyListeners();
      }

      await sink.flush();
      await sink.close();
      client.close();

      if (File(exePath).existsSync()) {
        try {
          File(exePath).deleteSync();
        } catch (_) {}
      }
      file.renameSync(exePath);

      _isDownloading = false;
      _downloadProgress = 1.0;
      _downloadStatus = 'Cloudflare Tunnel berhasil dipasang!';
      notifyListeners();
      return true;
    } catch (e) {
      _isDownloading = false;
      _downloadStatus = 'Gagal mengunduh: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> startTunnel({required String domain, int localPort = 80}) async {
    if (!isInstalled) {
      final ok = await downloadCloudflared();
      if (!ok) return false;
    }

    if (_isRunning) {
      await stopTunnel();
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
      ];

      _process = await Process.start(
        exe,
        args,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      final completer = Completer<String?>();

      void handleLog(String line) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty) {
          _logController.add('[Cloudflare Tunnel] $trimmed');
        }

        // Regex for Cloudflare Quick Tunnel URL: https://xxx.trycloudflare.com
        final reg = RegExp(r'https://[a-zA-Z0-9-]+\.trycloudflare\.com');
        final match = reg.firstMatch(line);
        if (match != null && !completer.isCompleted) {
          completer.complete(match.group(0));
        }
      }

      _process!.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        for (var l in data.split('\n')) {
          handleLog(l);
        }
      });

      _process!.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
        for (var l in data.split('\n')) {
          handleLog(l);
        }
      });

      _process!.exitCode.then((code) {
        if (_isRunning || _isStarting) {
          _isRunning = false;
          _isStarting = false;
          _publicUrl = null;
          if (code != 0 && _lastError == null) {
            _lastError = 'Proses tunnel keluar dengan kode $code';
          }
          notifyListeners();
        }
      });

      // Wait up to 20 seconds for Cloudflare edge to assign public URL
      final url = await completer.future.timeout(const Duration(seconds: 20), onTimeout: () => null);

      if (url != null) {
        _publicUrl = url;
        _isRunning = true;
        _isStarting = false;
        _startedAt = DateTime.now();
        _logController.add('[Cloudflare Tunnel] Online preview aktif: $url -> $domain');
        notifyListeners();
        return true;
      } else {
        _lastError = 'Timeout menunggu rute publik dari Cloudflare Edge (20s).';
        _isStarting = false;
        await stopTunnel();
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Gagal memulai tunnel: $e';
      _isStarting = false;
      await stopTunnel();
      notifyListeners();
      return false;
    }
  }

  Future<void> stopTunnel() async {
    if (_process != null) {
      try {
        _process!.kill();
      } catch (_) {}
      _process = null;
    }

    if (Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/T', '/IM', 'cloudflared.exe']);
      } catch (_) {}
    }

    _isRunning = false;
    _isStarting = false;
    _publicUrl = null;
    _activeDomain = null;
    _startedAt = null;
    _logController.add('[Cloudflare Tunnel] Tunnel dihentikan.');
    notifyListeners();
  }
}
