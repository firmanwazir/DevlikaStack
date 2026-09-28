import 'dart:io';
import 'package:path/path.dart' as p;

class PhpVersionModel {
  final String versionKey; // "7.4", "8.1", "8.2", "8.3"
  final String name; // "PHP 7.4 (Legacy / CI3)", "PHP 8.2 (Laravel 10/11 / CI4)"
  final String dirPath;
  final bool isInstalled;
  final String exactVersion;
  final String downloadUrl;

  const PhpVersionModel({
    required this.versionKey,
    required this.name,
    required this.dirPath,
    required this.isInstalled,
    required this.exactVersion,
    required this.downloadUrl,
  });

  String get phpExe => p.join(dirPath, 'php.exe');
  String get phpCgiExe {
    final cgi = p.join(dirPath, 'php-cgi.exe');
    if (File(cgi).existsSync()) return cgi;
    return phpExe;
  }
  String get phpIni => p.join(dirPath, 'php.ini');
}
