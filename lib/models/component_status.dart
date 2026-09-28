class ComponentItem {
  final String id;
  final String name;
  final String description;
  bool isInstalled;
  String version;
  String path;
  String? detectedLocalSource;
  bool isInstalling;
  double installProgress; // 0.0 to 1.0
  String statusMessage;

  ComponentItem({
    required this.id,
    required this.name,
    required this.description,
    this.isInstalled = false,
    this.version = 'Belum Terpasang',
    this.path = '',
    this.detectedLocalSource,
    this.isInstalling = false,
    this.installProgress = 0.0,
    this.statusMessage = '',
  });
}

class SystemComponents {
  ComponentItem php;
  ComponentItem mariaDb;
  ComponentItem phpMyAdmin;
  ComponentItem nginx;
  ComponentItem apache;

  SystemComponents({
    required this.php,
    required this.mariaDb,
    required this.phpMyAdmin,
    required this.nginx,
    required this.apache,
  });

  bool get canStartWebServer => php.isInstalled;
  bool get canStartMariaDb => mariaDb.isInstalled;
  bool get isAllInstalled =>
      php.isInstalled && mariaDb.isInstalled && phpMyAdmin.isInstalled;
}
