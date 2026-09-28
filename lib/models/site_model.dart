class SiteModel {
  final String id;
  String domain;
  String rootPath;
  String type; // "php", "static", "proxy"
  int proxyPort;
  String phpVersion; // e.g. "default", "7.4", "8.1", "8.2", "8.3"
  bool isEnabled;
  DateTime createdAt;

  SiteModel({
    required this.id,
    required this.domain,
    required this.rootPath,
    this.type = 'php',
    this.proxyPort = 3000,
    this.phpVersion = 'default',
    this.isEnabled = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory SiteModel.fromJson(Map<String, dynamic> json) {
    return SiteModel(
      id: json['id'] ?? '',
      domain: json['domain'] ?? '',
      rootPath: json['rootPath'] ?? '',
      type: json['type'] ?? 'php',
      proxyPort: json['proxyPort'] ?? 3000,
      phpVersion: json['phpVersion'] ?? 'default',
      isEnabled: json['isEnabled'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'domain': domain,
      'rootPath': rootPath,
      'type': type,
      'proxyPort': proxyPort,
      'phpVersion': phpVersion,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
