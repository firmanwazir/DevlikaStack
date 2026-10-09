import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../services/db_importer_service.dart';
import '../services/mariadb_manager.dart';
import '../theme/app_theme.dart';

class BigDbImporterWidget extends StatefulWidget {
  const BigDbImporterWidget({super.key});

  @override
  State<BigDbImporterWidget> createState() => _BigDbImporterWidgetState();
}

class _BigDbImporterWidgetState extends State<BigDbImporterWidget> {
  final TextEditingController _fileController = TextEditingController();
  final TextEditingController _dbNameController = TextEditingController();
  List<String> _existingDatabases = [];
  bool _isLoadingDatabases = false;
  String? _selectedExistingDb;
  bool _isNewDb = true;
  int _selectedFileSize = 0;

  @override
  void initState() {
    super.initState();
    _loadDatabases();
    final importer = DbImporterService.instance;
    if (importer.currentFilePath != null && _fileController.text.isEmpty) {
      _fileController.text = importer.currentFilePath!;
      final f = File(importer.currentFilePath!);
      if (f.existsSync()) {
        _selectedFileSize = f.lengthSync();
      }
    }
    if (importer.currentDatabase != null && _dbNameController.text.isEmpty) {
      _dbNameController.text = importer.currentDatabase!;
    }
  }

  @override
  void dispose() {
    _fileController.dispose();
    _dbNameController.dispose();
    super.dispose();
  }

  Future<void> _loadDatabases() async {
    if (!MariaDbManager.instance.isRunning) return;
    setState(() => _isLoadingDatabases = true);
    final dbs = await DbImporterService.instance.getDatabases();
    if (mounted) {
      setState(() {
        _existingDatabases = dbs;
        _isLoadingDatabases = false;
        if (dbs.isNotEmpty && _selectedExistingDb == null && !_isNewDb) {
          _selectedExistingDb = dbs.first;
        }
      });
    }
  }

  Future<void> _pickSqlFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sql'],
        dialogTitle: 'Pilih File Dump Database SQL (.sql)',
      );

      if (result != null && result.isNotEmpty && result.first.path != null) {
        final filePath = result.first.path!;
        final file = File(filePath);
        if (file.existsSync()) {
          final size = file.lengthSync();
          final baseName = p.basenameWithoutExtension(filePath);
          final suggestedDb = baseName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
              .replaceAll(RegExp(r'_+'), '_')
              .replaceAll(RegExp(r'^_+|_+$'), '');

          setState(() {
            _fileController.text = filePath;
            _selectedFileSize = size;
            if (_dbNameController.text.trim().isEmpty) {
              _dbNameController.text = suggestedDb;
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih file: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  Future<void> _startImport() async {
    final filePath = _fileController.text.trim();
    if (filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih file SQL terlebih dahulu.'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
      return;
    }

    final targetDb = _isNewDb
        ? _dbNameController.text.trim()
        : (_selectedExistingDb ?? _dbNameController.text.trim());

    if (targetDb.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tentukan nama database tujuan.'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(targetDb)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama database hanya boleh mengandung huruf, angka, dan underscore.'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
      return;
    }

    DbImporterService.instance.clearStatus();

    final success = await DbImporterService.instance.startImport(
      sqlFilePath: filePath,
      targetDatabase: targetDb,
      createDbIfNotExists: _isNewDb,
    );

    if (mounted) {
      if (success) {
        _loadDatabases();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import database `$targetDb` selesai dengan sukses.'),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (DbImporterService.instance.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal: ${DbImporterService.instance.errorMessage}'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DbImporterService.instance,
      builder: (context, _) {
        final importer = DbImporterService.instance;
        final isImporting = importer.isImporting;

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isImporting ? AppTheme.accentIndigo : AppTheme.borderDark,
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: const Center(
                          child: Icon(Icons.flash_on_rounded, color: AppTheme.accentIndigo, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Large Database Importer',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Optimal untuk file multi-gigabyte (1GB - 10GB+) dengan alokasi buffer sekuensial.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Text(
                      'CLI STREAM',
                      style: AppTheme.monoStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Inline Success Banner
              if (importer.lastCompletedInfo != null && !isImporting) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.accentGreen, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          importer.lastCompletedInfo!,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 15, color: AppTheme.textMuted),
                        tooltip: 'Tutup',
                        onPressed: () => importer.clearStatus(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              // Inline Error Banner
              if (importer.errorMessage != null && !isImporting) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.error_outline, color: AppTheme.accentRed, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Import Gagal',
                              style: TextStyle(
                                color: AppTheme.accentRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              importer.errorMessage!,
                              style: AppTheme.monoStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 15, color: AppTheme.textMuted),
                        tooltip: 'Tutup',
                        onPressed: () => importer.clearStatus(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],

              if (!isImporting) ...[
                // File SQL Selection Row
                const Text(
                  'File SQL Target',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fileController,
                        onChanged: (val) {
                          final trimmed = val.trim();
                          final f = File(trimmed);
                          if (f.existsSync()) {
                            final size = f.lengthSync();
                            final baseName = p.basenameWithoutExtension(trimmed);
                            final suggestedDb = baseName
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
                                .replaceAll(RegExp(r'_+'), '_')
                                .replaceAll(RegExp(r'^_+|_+$'), '');
                            setState(() {
                              _selectedFileSize = size;
                              if (_dbNameController.text.trim().isEmpty) {
                                _dbNameController.text = suggestedDb;
                              }
                            });
                          } else {
                            if (_selectedFileSize != 0) {
                              setState(() => _selectedFileSize = 0);
                            }
                          }
                        },
                        style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: r'D:\database_backup.sql',
                          hintStyle: const TextStyle(color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.surfaceSubtle,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppTheme.borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppTheme.borderDark),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppTheme.accentIndigo),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _pickSqlFile,
                      icon: const Icon(Icons.folder_open_outlined, size: 15),
                      label: Text(_selectedFileSize > 0
                          ? 'Pilih (${DbImporterService.formatBytes(_selectedFileSize)})'
                          : 'Pilih File .sql'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.borderDark),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
                if (_selectedFileSize >= 1024 * 1024 * 1024) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ukuran file: ${DbImporterService.formatBytes(_selectedFileSize)}. Pastikan partisi penyimpanan memiliki sisa ruang memadai.',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Database Target Selector
                Row(
                  children: [
                    // Segmented Button
                    InkWell(
                      onTap: () => setState(() => _isNewDb = true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isNewDb ? AppTheme.surfaceElevated : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _isNewDb ? AppTheme.accentIndigo : AppTheme.borderDark,
                          ),
                        ),
                        child: Text(
                          '+ Database Baru',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _isNewDb ? AppTheme.textPrimary : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() => _isNewDb = false);
                        _loadDatabases();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: !_isNewDb ? AppTheme.surfaceElevated : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: !_isNewDb ? AppTheme.accentIndigo : AppTheme.borderDark,
                          ),
                        ),
                        child: Text(
                          'Database yang Ada',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: !_isNewDb ? AppTheme.textPrimary : AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_isNewDb)
                  TextFormField(
                    controller: _dbNameController,
                    style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Nama Database Baru',
                      labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                      hintText: 'db_target_name',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surfaceSubtle,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.accentIndigo),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: _isLoadingDatabases
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 10),
                                  child: Center(
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentIndigo),
                                    ),
                                  ),
                                )
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _existingDatabases.contains(_selectedExistingDb)
                                        ? _selectedExistingDb
                                        : (_existingDatabases.isNotEmpty ? _existingDatabases.first : null),
                                    isExpanded: true,
                                    dropdownColor: AppTheme.cardDark,
                                    style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 12),
                                    items: _existingDatabases.map((db) {
                                      return DropdownMenuItem<String>(
                                        value: db,
                                        child: Text(db),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() => _selectedExistingDb = val);
                                    },
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.textSecondary),
                        tooltip: 'Muat ulang database',
                        onPressed: _loadDatabases,
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Start Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startImport,
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text(
                      'Mulai Import Database',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentIndigo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ] else ...[
                // Active Importing UI
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            importer.statusMessage,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(importer.progress * 100).toStringAsFixed(1)}%',
                            style: AppTheme.monoStyle(
                              color: AppTheme.accentIndigo,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: importer.progress > 0 ? importer.progress : null,
                          minHeight: 6,
                          backgroundColor: AppTheme.surfaceElevated,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentIndigo),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Stats Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Kecepatan',
                              value: '${importer.speedMBps.toStringAsFixed(1)} MB/s',
                              icon: Icons.speed_rounded,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Terproses',
                              value: '${DbImporterService.formatBytes(importer.bytesProcessed)} / ${DbImporterService.formatBytes(importer.totalBytes)}',
                              icon: Icons.data_usage_rounded,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Waktu Berjalan',
                              value: importer.elapsedText,
                              icon: Icons.timer_outlined,
                            ),
                          ),
                          Expanded(
                            child: _buildMetricTile(
                              label: 'Estimasi Tersisa',
                              value: importer.etaText,
                              icon: Icons.hourglass_empty_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Cancel Button
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: () => importer.cancelImport(),
                    icon: const Icon(Icons.stop_rounded, size: 14, color: AppTheme.accentRed),
                    label: const Text('Batalkan', style: TextStyle(color: AppTheme.accentRed, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.accentRed.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTheme.monoStyle(
            color: AppTheme.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
