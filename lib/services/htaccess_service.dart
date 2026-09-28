import 'dart:io';
import 'package:path/path.dart' as p;

class HtaccessResult {
  final bool isForbidden;
  final String? forbiddenReason;
  final bool isRedirect;
  final int redirectStatusCode;
  final String? redirectUrl;
  final String rewrittenPath;
  final String? pathInfo;
  final Map<String, String> responseHeaders;
  final Map<String, String> phpIniOverrides;
  final Map<String, String> customEnv;
  final bool disableIndexes;

  HtaccessResult({
    this.isForbidden = false,
    this.forbiddenReason,
    this.isRedirect = false,
    this.redirectStatusCode = 301,
    this.redirectUrl,
    required this.rewrittenPath,
    this.pathInfo,
    this.responseHeaders = const {},
    this.phpIniOverrides = const {},
    this.customEnv = const {},
    this.disableIndexes = true,
  });
}

class _RewriteCond {
  final String variable;
  final String pattern;
  final bool isOr;
  final bool isNoCase;
  final RegExp? regExp;
  final bool isFileTest;
  final bool isDirTest;
  final bool invert;

  _RewriteCond({
    required this.variable,
    required this.pattern,
    this.isOr = false,
    this.isNoCase = false,
  })  : isFileTest = pattern == '-f' || pattern == '!-f',
        isDirTest = pattern == '-d' || pattern == '!-d',
        invert = pattern.startsWith('!'),
        regExp = (pattern == '-f' || pattern == '!-f' || pattern == '-d' || pattern == '!-d')
            ? null
            : _compileRegex(pattern.startsWith('!') ? pattern.substring(1) : pattern, isNoCase);

  static RegExp? _compileRegex(String pat, bool isNoCase) {
    try {
      return RegExp(pat, caseSensitive: !isNoCase);
    } catch (_) {
      return null;
    }
  }
}

class _RewriteRule {
  final String pattern;
  final RegExp regExp;
  final String target;
  final bool isLast;
  final bool isForbidden;
  final bool isPassThrough;
  final int? redirectCode;
  final bool isQueryStringAppend;
  final bool isNoCase;
  final Map<String, String> envVars;
  final List<_RewriteCond> conditions;

  _RewriteRule({
    required this.pattern,
    required this.target,
    this.isLast = false,
    this.isForbidden = false,
    this.isPassThrough = false,
    this.redirectCode,
    this.isQueryStringAppend = true,
    this.isNoCase = false,
    this.envVars = const {},
    this.conditions = const [],
  }) : regExp = RegExp(pattern, caseSensitive: !isNoCase);
}

class _ParsedHtaccess {
  final DateTime lastModified;
  final bool disableIndexes;
  final List<_RewriteRule> rewriteRules;
  final List<RegExp> deniedFilesPatterns;
  final Map<String, String> phpIniOverrides;
  final Map<String, String> responseHeaders;

  _ParsedHtaccess({
    required this.lastModified,
    required this.disableIndexes,
    required this.rewriteRules,
    required this.deniedFilesPatterns,
    required this.phpIniOverrides,
    required this.responseHeaders,
  });
}

class HtaccessService {
  static final HtaccessService instance = HtaccessService._();
  HtaccessService._();

  final Map<String, _ParsedHtaccess> _cache = {};
  // Filesystem existence cache for RewriteCond -f/-d checks (avoids repeated disk I/O)
  final Map<String, bool> _fsExistsCache = {};
  // TTL for filesystem cache entries (auto-expire after 5 seconds to detect new files)
  DateTime _fsCacheLastClear = DateTime.now();

  void _checkFsCacheTtl() {
    final now = DateTime.now();
    if (now.difference(_fsCacheLastClear).inSeconds > 5) {
      _fsExistsCache.clear();
      _fsCacheLastClear = now;
    }
  }

  // Standard blocked files for web security
  static final List<RegExp> _alwaysBlockedPatterns = [
    RegExp(r'(^|[\\/])\.env(\..+)?$', caseSensitive: false),
    RegExp(r'(^|[\\/])\.git', caseSensitive: false),
    RegExp(r'(^|[\\/])\.htaccess$', caseSensitive: false),
    RegExp(r'(^|[\\/])\.htpasswd$', caseSensitive: false),
    RegExp(r'\.(sqlite|sqlite3|db)$', caseSensitive: false),
    RegExp(r'\.(sql|log|bak|conf)$', caseSensitive: false),
  ];

  HtaccessResult evaluate({
    required HttpRequest request,
    required String docRoot,
    required String rawPath,
    String? host,
  }) {
    // Auto-expire filesystem cache every 5 seconds
    _checkFsCacheTtl();

    final headers = <String, String>{};
    final phpIni = <String, String>{};
    final customEnv = <String, String>{};
    _ParsedHtaccess? parsed;

    final htaccessFile = File(p.join(docRoot, '.htaccess'));
    if (htaccessFile.existsSync()) {
      try {
        final stat = htaccessFile.statSync();
        final cached = _cache[htaccessFile.path];
        if (cached != null && cached.lastModified == stat.modified) {
          parsed = cached;
        } else {
          parsed = _parseHtaccess(htaccessFile.readAsStringSync(), stat.modified);
          if (_cache.length >= 100) {
            _cache.remove(_cache.keys.first);
          }
          _cache[htaccessFile.path] = parsed;
        }
        headers.addAll(parsed.responseHeaders);
        phpIni.addAll(parsed.phpIniOverrides);
      } catch (_) {}
    }

    // 1. Built-in hard security check (always protect .env, .git, etc.)
    final normalizedPath = rawPath.replaceAll(r'\', '/');
    for (var pattern in _alwaysBlockedPatterns) {
      if (pattern.hasMatch(normalizedPath)) {
        return HtaccessResult(
          isForbidden: true,
          forbiddenReason: 'Akses ke file sensitif ditolak (Devlika Stack Security).',
          rewrittenPath: rawPath,
          responseHeaders: headers,
          phpIniOverrides: phpIni,
        );
      }
    }

    if (parsed == null) {
      return HtaccessResult(rewrittenPath: rawPath);
    }

    // 3. Check FilesMatch Deny rules
    final fileName = p.basename(rawPath);
    for (var pattern in parsed.deniedFilesPatterns) {
      if (pattern.hasMatch(fileName) || pattern.hasMatch(normalizedPath)) {
        return HtaccessResult(
          isForbidden: true,
          forbiddenReason: 'File ini dilarang diakses oleh aturan .htaccess (<FilesMatch> Deny).',
          rewrittenPath: rawPath,
          responseHeaders: headers,
          phpIniOverrides: phpIni,
        );
      }
    }

    // 4. First evaluate all Forbidden [F] rules for security (Referrer spam, Bad bot, Blocked uploads/*.php)
    var currentPath = rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
    final forbiddenRules = parsed.rewriteRules.where((r) => r.isForbidden);
    for (var rule in forbiddenRules) {
      if (_evalConditions(rule.conditions, request, docRoot, currentPath, host)) {
        if (rule.regExp.hasMatch(currentPath) || rule.regExp.hasMatch(rawPath)) {
          return HtaccessResult(
            isForbidden: true,
            forbiddenReason: 'Akses ditolak oleh RewriteRule [F] pada .htaccess.',
            rewrittenPath: rawPath,
            responseHeaders: headers,
            phpIniOverrides: phpIni,
          );
        }
      }
    }

    // 5. Evaluate Rewrite / Routing Rules
    String? finalPathInfo;
    var finalRewritten = rawPath;

    final standardRules = parsed.rewriteRules.where((r) => !r.isForbidden);
    for (var rule in standardRules) {
      if (!_evalConditions(rule.conditions, request, docRoot, currentPath, host)) {
        continue;
      }

      final match = rule.regExp.firstMatch(currentPath);
      if (match != null) {
        // Collect environment variables set by rule
        customEnv.addAll(rule.envVars);

        // Check if rule is Forbidden [F]
        if (rule.isForbidden) {
          return HtaccessResult(
            isForbidden: true,
            forbiddenReason: 'Akses ditolak oleh RewriteRule [F] pada .htaccess.',
            rewrittenPath: rawPath,
            responseHeaders: headers,
            phpIniOverrides: phpIni,
          );
        }

        // Handle target substitution
        var target = rule.target;
        if (target != '-') {
          // Replace backreferences $0, $1, etc.
          for (var i = 0; i <= match.groupCount; i++) {
            final groupVal = match.group(i) ?? '';
            target = target.replaceAll('\$$i', groupVal);
          }

          // Check if redirect rule [R=301] or [R]
          if (rule.redirectCode != null) {
            var redirectLocation = target;
            if (!redirectLocation.startsWith('http://') &&
                !redirectLocation.startsWith('https://') &&
                !redirectLocation.startsWith('/')) {
              redirectLocation = '/$redirectLocation';
            }
            return HtaccessResult(
              isRedirect: true,
              redirectStatusCode: rule.redirectCode!,
              redirectUrl: redirectLocation,
              rewrittenPath: target,
              responseHeaders: headers,
              phpIniOverrides: phpIni,
            );
          }

          // CodeIgniter style: index.php/$0
          if (target.startsWith('index.php/')) {
            final subPath = target.substring('index.php'.length);
            finalPathInfo = subPath.startsWith('/') ? subPath : '/$subPath';
            finalRewritten = '/index.php';
          } else {
            finalRewritten = target.startsWith('/') ? target : '/$target';
          }

          currentPath = finalRewritten.startsWith('/') ? finalRewritten.substring(1) : finalRewritten;
        }

        if (rule.isLast) {
          break;
        }
      }
    }

    return HtaccessResult(
      rewrittenPath: finalRewritten,
      pathInfo: finalPathInfo,
      responseHeaders: headers,
      phpIniOverrides: phpIni,
      customEnv: customEnv,
      disableIndexes: parsed.disableIndexes,
    );
  }

  bool _evalConditions(
    List<_RewriteCond> conditions,
    HttpRequest request,
    String docRoot,
    String currentPath,
    String? host,
  ) {
    if (conditions.isEmpty) return true;

    // Apache evaluates conditions with AND by default, or OR when [OR] flag is present
    bool? currentOrGroupResult;

    for (var i = 0; i < conditions.length; i++) {
      final cond = conditions[i];
      final val = _resolveVariable(cond.variable, request, docRoot, currentPath, host);
      final isMatch = _evalSingleCondition(cond, val, docRoot);

      if (cond.isOr) {
        currentOrGroupResult = (currentOrGroupResult ?? false) || isMatch;
      } else {
        final result = (currentOrGroupResult != null)
            ? (currentOrGroupResult || isMatch)
            : isMatch;
        currentOrGroupResult = null;
        if (!result) return false;
      }
    }

    return currentOrGroupResult ?? true;
  }

  bool _evalSingleCondition(_RewriteCond cond, String value, String docRoot) {
    if (cond.isFileTest) {
      final path = p.isAbsolute(value) ? value : p.join(docRoot, value);
      final exists = _fsExistsCache[path] ??= File(path).existsSync();
      return cond.invert ? !exists : exists;
    }
    if (cond.isDirTest) {
      final path = p.isAbsolute(value) ? value : p.join(docRoot, value);
      final dirKey = 'd:$path';
      final exists = _fsExistsCache[dirKey] ??= Directory(path).existsSync();
      return cond.invert ? !exists : exists;
    }

    if (cond.regExp == null) return false;
    final matched = cond.regExp!.hasMatch(value);
    return cond.invert ? !matched : matched;
  }

  String _resolveVariable(
    String varName,
    HttpRequest request,
    String docRoot,
    String currentPath,
    String? host,
  ) {
    final upper = varName.toUpperCase().trim();
    if (upper == '%{REQUEST_FILENAME}') {
      return p.normalize(p.join(docRoot, currentPath));
    }
    if (upper == '%{REQUEST_URI}') {
      return request.uri.path;
    }
    if (upper == '%{HTTP_REFERER}') {
      return request.headers.value('referer') ?? '';
    }
    if (upper == '%{HTTP_USER_AGENT}') {
      return request.headers.value('user-agent') ?? '';
    }
    if (upper == '%{HTTP_HOST}') {
      return host ?? request.headers.value('host') ?? '';
    }
    if (upper == '%{QUERY_STRING}') {
      return request.uri.query;
    }
    if (upper == '%{REQUEST_METHOD}') {
      return request.method;
    }
    if (upper.startsWith('%{HTTP:') && upper.endsWith('}')) {
      final headerKey = varName.substring(7, varName.length - 1);
      return request.headers.value(headerKey) ?? '';
    }
    return '';
  }

  _ParsedHtaccess _parseHtaccess(String content, DateTime lastModified) {
    bool disableIndexes = true;
    final rewriteRules = <_RewriteRule>[];
    final deniedFilesPatterns = <RegExp>[];
    final phpIniOverrides = <String, String>{};
    final responseHeaders = <String, String>{};

    final lines = content.split(RegExp(r'\r?\n'));
    var pendingConditions = <_RewriteCond>[];
    var inFilesMatch = false;
    RegExp? currentFilesMatchRegex;

    for (var line in lines) {
      var trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Handle FilesMatch block
      final filesMatchStart = RegExp(r'^<FilesMatch\s+["\x27]?([^"\x27>]+)["\x27]?>', caseSensitive: false);
      final fmMatch = filesMatchStart.firstMatch(trimmed);
      if (fmMatch != null) {
        inFilesMatch = true;
        try {
          currentFilesMatchRegex = RegExp(fmMatch.group(1)!, caseSensitive: false);
        } catch (_) {}
        continue;
      }

      if (trimmed.toLowerCase().startsWith('</filesmatch>')) {
        inFilesMatch = false;
        currentFilesMatchRegex = null;
        continue;
      }

      if (inFilesMatch && currentFilesMatchRegex != null) {
        if (trimmed.toLowerCase().contains('deny from all') ||
            trimmed.toLowerCase().contains('require all denied')) {
          deniedFilesPatterns.add(currentFilesMatchRegex);
        }
        continue;
      }

      // Handle Options
      if (trimmed.toLowerCase().startsWith('options')) {
        if (trimmed.toLowerCase().contains('-indexes')) {
          disableIndexes = true;
        } else if (trimmed.toLowerCase().contains('+indexes')) {
          disableIndexes = false;
        }
        continue;
      }

      // Handle Header set
      final headerMatch = RegExp(r'^Header\s+set\s+([A-Za-z0-9_-]+)\s+["\x27]?([^"\x27]+)["\x27]?', caseSensitive: false);
      final hm = headerMatch.firstMatch(trimmed);
      if (hm != null) {
        responseHeaders[hm.group(1)!] = hm.group(2)!;
        continue;
      }

      // Handle php_value and php_flag
      final phpValMatch = RegExp(r'^php_value\s+([A-Za-z0-9_.-]+)\s+["\x27]?([^"\x27]+)["\x27]?', caseSensitive: false);
      final pvm = phpValMatch.firstMatch(trimmed);
      if (pvm != null) {
        phpIniOverrides[pvm.group(1)!] = pvm.group(2)!.trim();
        continue;
      }

      final phpFlagMatch = RegExp(r'^php_flag\s+([A-Za-z0-9_.-]+)\s+(on|off|1|0)', caseSensitive: false);
      final pfm = phpFlagMatch.firstMatch(trimmed);
      if (pfm != null) {
        final val = (pfm.group(2)!.toLowerCase() == 'on' || pfm.group(2) == '1') ? '1' : '0';
        phpIniOverrides[pfm.group(1)!] = val;
        continue;
      }

      // Handle loose key = value php ini settings in .htaccess
      final looseIniMatch = RegExp(r'^([A-Za-z0-9_.-]+)\s*=\s*["\x27]?([^"\x27]+)["\x27]?$');
      final lim = looseIniMatch.firstMatch(trimmed);
      if (lim != null) {
        final key = lim.group(1)!.trim();
        final val = lim.group(2)!.trim();
        if (key == 'max_input_vars' || key == 'memory_limit' || key == 'upload_max_filesize' || key == 'post_max_size') {
          phpIniOverrides[key] = val;
          continue;
        }
      }

      // Handle RewriteCond
      if (trimmed.toLowerCase().startsWith('rewritecond')) {
        final condMatch = RegExp(r'^RewriteCond\s+(\S+)\s+(\S+)(?:\s+\[([^\]]+)\])?', caseSensitive: false);
        final cm = condMatch.firstMatch(trimmed);
        if (cm != null) {
          final variable = cm.group(1)!;
          final pattern = cm.group(2)!;
          final flags = cm.group(3)?.toUpperCase() ?? '';
          final isOr = flags.contains('OR');
          final isNoCase = flags.contains('NC');

          pendingConditions.add(_RewriteCond(
            variable: variable,
            pattern: pattern,
            isOr: isOr,
            isNoCase: isNoCase,
          ));
        }
        continue;
      }

      // Handle RewriteRule
      if (trimmed.toLowerCase().startsWith('rewriterule')) {
        final ruleMatch = RegExp(r'^RewriteRule\s+(\S+)\s+(\S+)(?:\s+\[([^\]]+)\])?', caseSensitive: false);
        final rm = ruleMatch.firstMatch(trimmed);
        if (rm != null) {
          final pattern = rm.group(1)!;
          final target = rm.group(2)!;
          final flags = rm.group(3)?.toUpperCase() ?? '';

          final isLast = flags.contains('L');
          final isForbidden = flags.contains('F');
          final isPassThrough = flags.contains('PT');
          final isNoCase = flags.contains('NC');
          final isQSA = flags.contains('QSA');

          int? redirectCode;
          if (flags.contains('R=301')) {
            redirectCode = 301;
          } else if (flags.contains('R=302') || flags.contains('R')) {
            redirectCode = 302;
          }

          // Parse env vars [E=VAR:VAL]
          final envMap = <String, String>{};
          final envMatch = RegExp(r'E=([A-Za-z0-9_-]+):([^\],]+)');
          for (var em in envMatch.allMatches(flags)) {
            envMap[em.group(1)!] = em.group(2)!;
          }

          rewriteRules.add(_RewriteRule(
            pattern: pattern,
            target: target,
            isLast: isLast,
            isForbidden: isForbidden,
            isPassThrough: isPassThrough,
            redirectCode: redirectCode,
            isQueryStringAppend: isQSA,
            isNoCase: isNoCase,
            envVars: envMap,
            conditions: List.from(pendingConditions),
          ));

          pendingConditions.clear();
        }
        continue;
      }
    }

    return _ParsedHtaccess(
      lastModified: lastModified,
      disableIndexes: disableIndexes,
      rewriteRules: rewriteRules,
      deniedFilesPatterns: deniedFilesPatterns,
      phpIniOverrides: phpIniOverrides,
      responseHeaders: responseHeaders,
    );
  }
}
