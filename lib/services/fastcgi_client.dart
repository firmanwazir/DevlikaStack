import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Lightweight FastCGI client for communicating with php-cgi in FastCGI daemon mode.
///
/// **WHY THIS EXISTS:**
/// Previously, every PHP request spawned a new `php-cgi.exe` via `Process.start()`.
/// On Windows, process creation overhead is ~50-200ms PER REQUEST.
/// With FastCGI, php-cgi runs once as a persistent daemon and accepts requests
/// via TCP socket (localhost:port), reducing per-request overhead to ~0.1ms.
///
/// FastCGI Protocol Reference: https://fastcgi-archives.github.io/FastCGI_Specification.html
class FastCgiClient {
  final String host;
  final int port;
  int _requestId = 0;

  // FastCGI record types
  static const int _typeBeginRequest = 1;
  static const int _typeEndRequest = 3;
  static const int _typeParams = 4;
  static const int _typeStdin = 5;
  static const int _typeStdout = 6;
  static const int _typeStderr = 7;

  // FastCGI roles & flags
  static const int _roleResponder = 1;

  FastCgiClient({this.host = '127.0.0.1', this.port = 9123});

  int get _nextRequestId {
    _requestId = (_requestId + 1) & 0xFFFF;
    if (_requestId == 0) _requestId = 1;
    return _requestId;
  }

  /// Execute a PHP script via FastCGI protocol.
  /// [params] are the CGI environment variables (SCRIPT_FILENAME, REQUEST_URI, etc.)
  /// [stdinData] is the request body (POST data).
  /// Returns stdout and stderr byte streams, identical to what Process.start() would produce.
  Future<FastCgiResponse> execute({
    required Map<String, String> params,
    List<int> stdinData = const [],
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(host, port,
          timeout: const Duration(milliseconds: 1000));
      // Disable Nagle's algorithm for lower latency
      socket.setOption(SocketOption.tcpNoDelay, true);

      final reqId = _nextRequestId;

      // Build entire request as a single buffer for one write() call
      final sender = BytesBuilder(copy: false);

      // 1. BEGIN_REQUEST
      sender.add(_buildRecord(_typeBeginRequest, reqId, _beginRequestBody()));

      // 2. PARAMS (split into max 65535 byte chunks)
      final encodedParams = _encodeParams(params);
      var i = 0;
      while (i < encodedParams.length) {
        final end = (i + 65535 > encodedParams.length)
            ? encodedParams.length
            : i + 65535;
        sender.add(
            _buildRecord(_typeParams, reqId, encodedParams.sublist(i, end)));
        i = end;
      }
      // Empty PARAMS = end of params stream
      sender.add(_buildRecord(_typeParams, reqId, Uint8List(0)));

      // 3. STDIN (request body, split into chunks)
      if (stdinData.isNotEmpty) {
        i = 0;
        while (i < stdinData.length) {
          final end = (i + 65535 > stdinData.length)
              ? stdinData.length
              : i + 65535;
          sender.add(_buildRecord(
              _typeStdin, reqId, Uint8List.fromList(stdinData.sublist(i, end))));
          i = end;
        }
      }
      // Empty STDIN = end of stdin stream
      sender.add(_buildRecord(_typeStdin, reqId, Uint8List(0)));

      // Send everything in one shot
      socket.add(sender.takeBytes());

      // 4. Read and parse response records
      final stdoutBuilder = BytesBuilder(copy: false);
      final stderrBuilder = BytesBuilder(copy: false);
      final pendingBytes = BytesBuilder(copy: false);

      final completer = Completer<void>();
      late final StreamSubscription<Uint8List> sub;
      sub = socket.listen(
        (data) {
          pendingBytes.add(data);
          final bytes = pendingBytes.takeBytes();
          var offset = 0;

          while (offset + 8 <= bytes.length) {
            final contentLength =
                (bytes[offset + 4] << 8) | bytes[offset + 5];
            final paddingLength = bytes[offset + 6];
            final totalRecordLen = 8 + contentLength + paddingLength;

            if (offset + totalRecordLen > bytes.length) {
              // Incomplete record — save remainder for next data event
              break;
            }

            final type = bytes[offset + 1];

            if (type == _typeStdout && contentLength > 0) {
              stdoutBuilder
                  .add(bytes.sublist(offset + 8, offset + 8 + contentLength));
            } else if (type == _typeStderr && contentLength > 0) {
              stderrBuilder
                  .add(bytes.sublist(offset + 8, offset + 8 + contentLength));
            } else if (type == _typeEndRequest) {
              if (!completer.isCompleted) {
                completer.complete();
              }
            }

            offset += totalRecordLen;
          }

          // Save any remaining partial record
          if (offset < bytes.length) {
            pendingBytes.add(bytes.sublist(offset));
          }
        },
        onError: (err) {
          if (!completer.isCompleted) completer.completeError(err);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future.timeout(timeout);
      try {
        await sub.cancel();
      } catch (_) {}

      return FastCgiResponse(
        stdout: stdoutBuilder.takeBytes(),
        stderr: stderrBuilder.takeBytes(),
        success: true,
      );
    } catch (e) {
      return FastCgiResponse(
        stdout: [],
        stderr: [],
        success: false,
        error: e.toString(),
      );
    } finally {
      try {
        await socket?.flush();
        await socket?.close();
      } catch (_) {
        try {
          socket?.destroy();
        } catch (_) {}
      }
    }
  }

  Uint8List _beginRequestBody() {
    final body = Uint8List(8);
    body[0] = (_roleResponder >> 8) & 0xFF;
    body[1] = _roleResponder & 0xFF;
    body[2] = 0; // flags (no keep-conn, simpler lifecycle)
    return body;
  }

  Uint8List _buildRecord(int type, int requestId, List<int> content) {
    final contentLength = content.length;
    final paddingLength = (8 - (contentLength % 8)) % 8;
    final record = Uint8List(8 + contentLength + paddingLength);
    record[0] = 1; // FastCGI version
    record[1] = type;
    record[2] = (requestId >> 8) & 0xFF;
    record[3] = requestId & 0xFF;
    record[4] = (contentLength >> 8) & 0xFF;
    record[5] = contentLength & 0xFF;
    record[6] = paddingLength;
    record[7] = 0; // reserved
    if (contentLength > 0) {
      record.setRange(8, 8 + contentLength, content);
    }
    return record;
  }

  Uint8List _encodeParams(Map<String, String> params) {
    final builder = BytesBuilder(copy: false);
    params.forEach((name, value) {
      final nameBytes = Uint8List.fromList(name.codeUnits);
      final valueBytes = Uint8List.fromList(value.codeUnits);
      builder.add(_encodeLength(nameBytes.length));
      builder.add(_encodeLength(valueBytes.length));
      builder.add(nameBytes);
      builder.add(valueBytes);
    });
    return Uint8List.fromList(builder.takeBytes());
  }

  Uint8List _encodeLength(int length) {
    if (length < 128) {
      return Uint8List.fromList([length]);
    } else {
      return Uint8List.fromList([
        ((length >> 24) & 0xFF) | 0x80,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ]);
    }
  }
}

/// Result from a FastCGI request execution
class FastCgiResponse {
  final List<int> stdout;
  final List<int> stderr;
  final bool success;
  final String? error;

  const FastCgiResponse({
    required this.stdout,
    required this.stderr,
    required this.success,
    this.error,
  });
}
