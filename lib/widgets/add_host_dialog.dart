import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/site_model.dart';
import '../services/server_controller.dart';
import '../services/php_manager.dart';
import '../theme/app_theme.dart';

class AddHostDialog extends StatefulWidget {
  final SiteModel? siteToEdit;

  const AddHostDialog({super.key, this.siteToEdit});

  @override
  State<AddHostDialog> createState() => _AddHostDialogState();
}

class _AddHostDialogState extends State<AddHostDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _domainController;
  late final TextEditingController _pathController;
  late final TextEditingController _proxyPortController;
  late String _selectedType; // 'php', 'proxy'
  late String _selectedPhpVersion;
  bool _isEnabled = true;

  bool get isEditing => widget.siteToEdit != null;

  @override
  void initState() {
    super.initState();
    PhpManager.instance.getVersions(forceReload: true);
    final s = widget.siteToEdit;
    _domainController = TextEditingController(text: s?.domain ?? '');
    _pathController = TextEditingController(text: s?.rootPath ?? '');
    _proxyPortController = TextEditingController(text: s != null ? s.proxyPort.toString() : '3000');
    _selectedType = s?.type ?? 'php';
    _selectedPhpVersion = s?.phpVersion ?? 'default';
    _isEnabled = s?.isEnabled ?? true;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _pathController.dispose();
    _proxyPortController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final result = await FilePickerPlatform.instance.getDirectoryPath(
      dialogTitle: 'Pilih Folder Proyek Website',
    );
    if (result != null) {
      // Don't auto-redirect to public/ — _handleFileOrPhp() handles framework detection
      setState(() {
        _pathController.text = result;
      });
    }
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      final domain = _domainController.text.trim().toLowerCase();
      final rootPath = _pathController.text.trim();
      final proxyPort = int.tryParse(_proxyPortController.text.trim()) ?? 3000;

      if (isEditing) {
        final updatedSite = SiteModel(
          id: widget.siteToEdit!.id,
          domain: domain,
          rootPath: rootPath,
          type: _selectedType,
          proxyPort: proxyPort,
          phpVersion: _selectedPhpVersion,
          isEnabled: _isEnabled,
        );

        ServerController.instance.updateSite(
          updatedSite,
          oldDomain: widget.siteToEdit!.domain,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Website $domain berhasil diperbarui!'),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final newSite = SiteModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          domain: domain,
          rootPath: rootPath,
          type: _selectedType,
          proxyPort: proxyPort,
          phpVersion: _selectedPhpVersion,
          isEnabled: true,
        );

        ServerController.instance.addSite(newSite);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Website $domain berhasil ditambahkan!'),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit Website (Host)' : 'Tambah Website (Host)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isEditing
                            ? 'Perbarui konfigurasi domain & direktori'
                            : 'Daftarkan domain lokal ke web server',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Domain Name
              const Text(
                'Nama Domain Lokal',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _domainController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'contoh: tokoku.local atau myweb.test',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderDark),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Domain wajib diisi';
                  final domain = val.trim().toLowerCase();
                  final domainRegex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
                  if (!domainRegex.hasMatch(domain)) {
                    return 'Format domain tidak valid (gunakan huruf, angka, titik, atau strip)';
                  }
                  if (domain == 'localhost' || domain == '127.0.0.1') {
                    return 'Nama domain $domain tidak dapat digunakan';
                  }

                  // Check duplicate domain
                  final existingSites = ServerController.instance.sites;
                  final isDuplicate = existingSites.any((s) =>
                      s.domain.toLowerCase() == domain &&
                      (isEditing ? s.id != widget.siteToEdit!.id : true));
                  if (isDuplicate) return 'Domain ini sudah terdaftar';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Type Selector
              const Text(
                'Tipe Website',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      'PHP / Web Statis',
                      'File HTML/PHP dari folder',
                      'php',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypeOption(
                      'Reverse Proxy',
                      'Port Node/Vite (3000, 5173)',
                      'proxy',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Target Folder (for PHP)
              if (_selectedType == 'php') ...[
                const Text(
                  'Folder Proyek',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _pathController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: r'D:\WebServer\www\proyek_kamu',
                          hintStyle: const TextStyle(color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.bgDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderDark),
                          ),
                        ),
                        validator: (val) {
                          if (_selectedType == 'php' && (val == null || val.trim().isEmpty)) {
                            return 'Folder proyek wajib diisi';
                          }
                          if (_selectedType == 'php' && val != null && val.trim().isNotEmpty && !Directory(val.trim()).existsSync()) {
                            return 'Folder tidak ditemukan di lokasi ini';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _pickFolder,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cardHover,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Pilih Folder'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // PHP Version Selection
                const Text(
                  'Versi PHP untuk Website Ini',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPhpVersion,
                      dropdownColor: AppTheme.cardDark,
                      isExpanded: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [
                        const DropdownMenuItem(
                          value: 'default',
                          child: Text('⚡ Otomatis (Versi Default Terpasang)'),
                        ),
                        ...PhpManager.instance.getVersions().map((v) {
                          return DropdownMenuItem(
                            value: v.versionKey,
                            child: Row(
                              children: [
                                Icon(
                                  v.isInstalled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 14,
                                  color: v.isInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${v.name} ${v.isInstalled ? "(v${v.exactVersion})" : "(Belum Dipasang)"}',
                                  style: TextStyle(
                                    color: v.isInstalled ? Colors.white : AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPhpVersion = val);
                        }
                      },
                    ),
                  ),
                ),
              ],

              // Proxy Port (for Proxy)
              if (_selectedType == 'proxy') ...[
                const Text(
                  'Port Lokal Aplikasi (Node / Next.js / Vite)',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _proxyPortController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: '3000 atau 5173',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.bgDark,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderDark),
                    ),
                  ),
                  validator: (val) {
                    if (_selectedType == 'proxy') {
                      final port = int.tryParse(val?.trim() ?? '');
                      if (port == null || port <= 0 || port > 65535) {
                        return 'Port harus berupa angka valid (1 - 65535)';
                      }
                    }
                    return null;
                  },
                ),
              ],

              // Status Toggle (if editing)
              if (isEditing) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isEnabled ? Icons.check_circle_rounded : Icons.pause_circle_filled_rounded,
                            size: 18,
                            color: _isEnabled ? AppTheme.accentGreen : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status Website: ${_isEnabled ? "Aktif" : "Nonaktif (Dimatikan)"}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isEnabled ? AppTheme.accentGreen : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _isEnabled,
                        activeColor: AppTheme.accentGreen,
                        onChanged: (val) => setState(() => _isEnabled = val),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 22),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isEditing ? 'Simpan Perubahan' : 'Simpan & Aktifkan',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String title, String desc, String type) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue.withOpacity(0.12) : AppTheme.bgDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accentBlue : AppTheme.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
