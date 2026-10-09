class PhpExtensionModel {
  final String key;
  final String name;
  final String category;
  final String description;
  final bool isZend;
  final bool isEnabled;
  final bool isAvailableOnDisk;

  const PhpExtensionModel({
    required this.key,
    required this.name,
    required this.category,
    required this.description,
    this.isZend = false,
    required this.isEnabled,
    this.isAvailableOnDisk = true,
  });

  PhpExtensionModel copyWith({
    String? key,
    String? name,
    String? category,
    String? description,
    bool? isZend,
    bool? isEnabled,
    bool? isAvailableOnDisk,
  }) {
    return PhpExtensionModel(
      key: key ?? this.key,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      isZend: isZend ?? this.isZend,
      isEnabled: isEnabled ?? this.isEnabled,
      isAvailableOnDisk: isAvailableOnDisk ?? this.isAvailableOnDisk,
    );
  }
}
