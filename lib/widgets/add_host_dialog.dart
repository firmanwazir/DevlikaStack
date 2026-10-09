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
      dialogTitle: 'Pilih Direktori Root Host',
    );
    if (result != null) {
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
            content: Text('Virtual host $domain berhasil diperbarui.'),
            backgroundColor: AppTheme.cardDark,
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
            content: Text('Virtual host $domain berhasil ditambahkan.'),
            backgroundColor: AppTheme.cardDark,
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
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
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
                        isEditing ? 'Edit Virtual Host' : 'Tambah Virtual Host Baru',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing
                            ? 'Perbarui konfigurasi domain dan direktori root proyek'
                            : 'Konfigurasikan domain lokal dan runtime target',
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                    splashRadius: 16,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Domain Name
              const Text(
                'Domain Host Lokal',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: TextFormField(
                  controller: _domainController,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: AppTheme.monoFont),
                  decoration: InputDecoration(
                    hintText: 'contoh: project.local atau api.test',
                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: AppTheme.surfaceSubtle,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.borderDark),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: AppTheme.borderDark),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Domain wajib diisi';
                    final domain = val.trim().toLowerCase();
                    final domainRegex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
                    if (!domainRegex.hasMatch(domain)) {
                      return 'Format domain tidak valid';
                    }
                    if (domain == 'localhost' || domain == '127.0.0.1') {
                      return 'Domain $domain tidak dapat digunakan';
                    }

                    final existingSites = ServerController.instance.sites;
                    final isDuplicate = existingSites.any((s) =>
                        s.domain.toLowerCase() == domain &&
                        (isEditing ? s.id != widget.siteToEdit!.id : true));
                    if (isDuplicate) return 'Domain sudah terdaftar';
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Type Selector
              const Text(
                'Tipe Runtime',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      'PHP / FastCGI',
                      'Document Root & FastCGI Pool',
                      'php',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTypeOption(
                      'Reverse Proxy',
                      'Forward ke port lokal (Node/Vite)',
                      'proxy',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Target Folder (for PHP)
              if (_selectedType == 'php') ...[
                const Text(
                  'Document Root (Direktori Proyek)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextFormField(
                          controller: _pathController,
                          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontFamily: AppTheme.monoFont),
                          decoration: InputDecoration(
                            hintText: r'D:\WebServer\www\my-project',
                            hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            filled: true,
                            fillColor: AppTheme.surfaceSubtle,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTheme.borderDark),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: AppTheme.borderDark),
                            ),
                          ),
                          validator: (val) {
                            if (_selectedType == 'php' && (val == null || val.trim().isEmpty)) {
                              return 'Direktori root wajib diisi';
                            }
                            if (_selectedType == 'php' && val != null && val.trim().isNotEmpty && !Directory(val.trim()).existsSync()) {
                              return 'Direktori tidak ditemukan';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: OutlinedButton(
                        onPressed: _pickFolder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          backgroundColor: AppTheme.surfaceSubtle,
                          side: const BorderSide(color: AppTheme.borderDark),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Browse...', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // PHP Version Selection
                const Text(
                  'Versi PHP',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPhpVersion,
                      dropdownColor: AppTheme.cardDark,
                      isExpanded: true,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontFamily: AppTheme.monoFont),
                      items: [
                        const DropdownMenuItem(
                          value: 'default',
                          child: Text('Default (Sistem Stack)'),
                        ),
                        ...PhpManager.instance.getVersions().map((v) {
                          return DropdownMenuItem(
                            value: v.versionKey,
                            child: Text('${v.name} ${v.isInstalled ? "(v${v.exactVersion})" : "(Belum Ada)"}'),
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
                  'Target Port Localhost',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  child: TextFormField(
                    controller: _proxyPortController,
                    style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontFamily: AppTheme.monoFont),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '3000 atau 5173',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: AppTheme.surfaceSubtle,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderDark),
                      ),
                    ),
                    validator: (val) {
                      if (_selectedType == 'proxy') {
                        final port = int.tryParse(val?.trim() ?? '');
                        if (port == null || port <= 0 || port > 65535) {
                          return 'Port harus angka 1 - 65535';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],

              // Status Toggle (if editing)
              if (isEditing) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isEnabled ? AppTheme.accentGreen : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Status Host: ${_isEnabled ? "Aktif" : "Nonaktif"}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isEnabled ? AppTheme.accentGreen : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Transform.scale(
                        scale: 0.72,
                        child: Switch(
                          value: _isEnabled,
                          activeColor: AppTheme.accentGreen,
                          onChanged: (val) => setState(() => _isEnabled = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentIndigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      isEditing ? 'Simpan Perubahan' : 'Tambah Host',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E2330) : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E374A) : AppTheme.borderDark,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              desc,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
