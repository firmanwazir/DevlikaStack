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
          // Suggest clean database name
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
            content: Text('Import database `$targetDb` berhasil diselesaikan!'),
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

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isImporting
                  ? AppTheme.accentCyan.withOpacity(0.6)
                  : AppTheme.borderDark,
              width: isImporting ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.accentCyan, AppTheme.accentBlue],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentCyan.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Big Database Turbo Importer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Khusus file besar (1 GB, 2 GB, 10 GB+) • 0 MB RAM Overhead • Optimal untuk HDD & SSD',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.accentCyan.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Direct CLI Stream',
                        style: TextStyle(
                          color: AppTheme.accentCyan,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Import query SQL langsung melalui client MariaDB lokal dengan buffer sekuensial dan penanganan transaksi InnoDB yang optimal.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 18),

                // Inline Success Banner
                if (importer.lastCompletedInfo != null && !isImporting) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppTheme.accentGreen, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            importer.lastCompletedInfo!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                          tooltip: 'Tutup notifikasi',
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentRed.withOpacity(0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Import Gagal',
                                style: TextStyle(
                                  color: AppTheme.accentRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                importer.errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontFamily: 'Consolas',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                          tooltip: 'Tutup notifikasi',
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Consolas'),
                          decoration: InputDecoration(
                            hintText: r'D:\backup_database_2gb.sql',
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
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _pickSqlFile,
                        icon: const Icon(Icons.file_open_rounded, size: 16),
                        label: Text(_selectedFileSize > 0
                            ? 'Pilih File (${DbImporterService.formatBytes(_selectedFileSize)})'
                            : 'Pilih File .sql'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.cardHover,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedFileSize >= 1024 * 1024 * 1024) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storage_rounded, size: 16, color: AppTheme.accentCyan),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ukuran file: ${DbImporterService.formatBytes(_selectedFileSize)}. Pastikan partisi penyimpanan memiliki sisa ruang yang cukup untuk data dan indeks tabel.',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Database Target Selector
                  Row(
                    children: [
                      // Toggle Database Type
                      InkWell(
                        onTap: () => setState(() => _isNewDb = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isNewDb ? AppTheme.accentCyan.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isNewDb ? AppTheme.accentCyan : AppTheme.borderDark,
                            ),
                          ),
                          child: Text(
                            '+ Database Baru',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _isNewDb ? AppTheme.accentCyan : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          setState(() => _isNewDb = false);
                          _loadDatabases();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: !_isNewDb ? AppTheme.accentCyan.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: !_isNewDb ? AppTheme.accentCyan : AppTheme.borderDark,
                            ),
                          ),
                          child: Text(
                            'Database yang Ada',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: !_isNewDb ? AppTheme.accentCyan : AppTheme.textMuted,
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
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Nama Database Baru',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        hintText: 'contoh: db_ecommerce_baru',
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
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.bgDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.borderDark),
                            ),
                            child: _isLoadingDatabases
                                ? const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
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
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
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
                          icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.accentCyan),
                          tooltip: 'Muat ulang daftar database',
                          onPressed: _loadDatabases,
                        ),
                      ],
                    ),

                  const SizedBox(height: 18),

                  // Start Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startImport,
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text(
                        'Mulai Import',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ] else ...[
                  // Active Importing UI (Real-time progress, speed, ETA)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
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
                                color: AppTheme.accentCyan,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${(importer.progress * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Consolas',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: importer.progress > 0 ? importer.progress : null,
                            minHeight: 10,
                            backgroundColor: Colors.white10,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Stats Grid (Speed, Transferred, ETA, Elapsed)
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
                                icon: Icons.timer_rounded,
                              ),
                            ),
                            Expanded(
                              child: _buildMetricTile(
                                label: 'Estimasi Tersisa',
                                value: importer.etaText,
                                icon: Icons.hourglass_top_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Cancel Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => importer.cancelImport(),
                      icon: const Icon(Icons.stop_rounded, size: 16, color: AppTheme.accentRed),
                      label: const Text('Batalkan Import', style: TextStyle(color: AppTheme.accentRed)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.accentRed),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
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
            Icon(icon, size: 12, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Consolas',
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
