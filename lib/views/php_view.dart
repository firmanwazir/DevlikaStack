import 'dart:io';
import 'package:flutter/material.dart';
import '../services/php_manager.dart';
import '../services/server_controller.dart';
import '../services/version_checker_service.dart';
import '../theme/app_theme.dart';

class PhpView extends StatefulWidget {
  const PhpView({super.key});

  @override
  State<PhpView> createState() => _PhpViewState();
}

class _PhpViewState extends State<PhpView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedVersionKey = '8.2';
  final _formKey = GlobalKey<FormState>();

  final _memoryLimitCtrl = TextEditingController(text: '512M');
  final _uploadMaxCtrl = TextEditingController(text: '128M');
  final _postMaxCtrl = TextEditingController(text: '128M');
  final _maxExecTimeCtrl = TextEditingController(text: '300');
  final _maxInputVarsCtrl = TextEditingController(text: '5000');
  final _timezoneCtrl = TextEditingController(text: 'Asia/Jakarta');
  String _fixPathinfo = '1';
  String _displayErrors = 'On';

  bool _isSaving = false;
  bool _isCheckingPhpUpdates = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSelectedVersion();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (VersionCheckerService.instance.phpUpdates.isEmpty) {
        VersionCheckerService.instance.checkPhp();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _memoryLimitCtrl.dispose();
    _uploadMaxCtrl.dispose();
    _postMaxCtrl.dispose();
    _maxExecTimeCtrl.dispose();
    _maxInputVarsCtrl.dispose();
    _timezoneCtrl.dispose();
    super.dispose();
  }

  void _initSelectedVersion() {
    final versions = PhpManager.instance.getVersions();
    final installed = versions.where((v) => v.isInstalled).toList();
    if (installed.isNotEmpty) {
      final p82 = installed.where((v) => v.versionKey == '8.2').firstOrNull;
      _selectedVersionKey = p82?.versionKey ?? installed.first.versionKey;
    }
    _loadCurrentIniValues();
  }

  void _loadCurrentIniValues() {
    final versions = PhpManager.instance.getVersions();
    final current = versions.where((v) => v.versionKey == _selectedVersionKey).firstOrNull;
    if (current == null || !current.isInstalled) return;

    final values = PhpManager.instance.readDirectives(current.phpIni);
    setState(() {
      _memoryLimitCtrl.text = values['memory_limit'] ?? '512M';
      _uploadMaxCtrl.text = values['upload_max_filesize'] ?? '128M';
      _postMaxCtrl.text = values['post_max_size'] ?? '128M';
      _maxExecTimeCtrl.text = values['max_execution_time'] ?? '300';
      _maxInputVarsCtrl.text = values['max_input_vars'] ?? '5000';
      _timezoneCtrl.text = values['date.timezone'] ?? 'Asia/Jakarta';
      _fixPathinfo = values['cgi.fix_pathinfo'] == '0' ? '0' : '1';
      _displayErrors = values['display_errors'] == 'Off' ? 'Off' : 'On';
    });
  }

  void _saveIniValues() {
    final versions = PhpManager.instance.getVersions();
    final current = versions.where((v) => v.versionKey == _selectedVersionKey).firstOrNull;
    if (current == null || !current.isInstalled) return;

    setState(() => _isSaving = true);

    final directives = {
      'memory_limit': _memoryLimitCtrl.text.trim(),
      'upload_max_filesize': _uploadMaxCtrl.text.trim(),
      'post_max_size': _postMaxCtrl.text.trim(),
      'max_execution_time': _maxExecTimeCtrl.text.trim(),
      'max_input_vars': _maxInputVarsCtrl.text.trim(),
      'cgi.fix_pathinfo': _fixPathinfo,
      'date.timezone': _timezoneCtrl.text.trim(),
      'display_errors': _displayErrors,
    };

    PhpManager.instance.saveDirectives(current.phpIni, directives);

    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Konfigurasi php.ini (${current.name}) berhasil disimpan!'),
        backgroundColor: AppTheme.accentGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openInNotepad(String iniPath) {
    if (File(iniPath).existsSync()) {
      Process.run('notepad.exe', [iniPath]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File php.ini belum ada untuk versi ini.'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
    }
  }

  Future<void> _checkPhpUpdates() async {
    setState(() => _isCheckingPhpUpdates = true);
    await VersionCheckerService.instance.checkPhp();
    if (mounted) {
      setState(() => _isCheckingPhpUpdates = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemeriksaan versi PHP selesai.'),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _installPhpVersion(String versionKey) async {
    final statusNotifier = ValueNotifier<String>('Memulai instalasi PHP $versionKey...');
    final progressNotifier = ValueNotifier<double>(0.1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.borderDark),
          ),
          title: Row(
            children: [
              const Icon(Icons.download_rounded, color: AppTheme.accentCyan, size: 20),
              const SizedBox(width: 8),
              Text('Instalasi PHP $versionKey', style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (_, status, __) => Text(status, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, __) => LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.borderDark,
                  color: AppTheme.accentCyan,
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      await PhpManager.instance.installVersion(
        versionKey,
        onProgress: (msg, prog) {
          statusNotifier.value = msg;
          progressNotifier.value = prog;
        },
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {});
        _loadCurrentIniValues();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PHP $versionKey berhasil dipasang.'),
            backgroundColor: AppTheme.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memasang PHP $versionKey: $e'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      statusNotifier.dispose();
      progressNotifier.dispose();
    }
  }

  Future<void> _uninstallPhpVersion(String versionKey) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
        title: const Text('Hapus PHP', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text('Hapus direktori binary dan konfigurasi PHP $versionKey?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await PhpManager.instance.uninstallVersion(versionKey);
      setState(() {
        _initSelectedVersion();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PHP $versionKey berhasil dihapus.'),
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
      animation: Listenable.merge([
        ServerController.instance,
        VersionCheckerService.instance,
      ]),
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Tab Navigation Bar
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.accentBlue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accentBlue.withOpacity(0.5)),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined, size: 18),
                      text: 'Versi PHP',
                    ),
                    Tab(
                      icon: Icon(Icons.tune_rounded, size: 18),
                      text: 'Konfigurasi php.ini',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVersionsTab(),
                    _buildIniEditorTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 1: VERSIONS & UPDATE DETECTION
  Widget _buildVersionsTab() {
    final versions = PhpManager.instance.getVersions();
    final updates = VersionCheckerService.instance.phpUpdates;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card with Update Checker
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.borderDark),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentPurple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.code_rounded, color: AppTheme.accentPurple, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Manajemen Versi PHP',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Kelola multiple binary PHP secara berdampingan. Setiap virtual host dapat menggunakan versi PHP berbeda.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isCheckingPhpUpdates ? null : _checkPhpUpdates,
                    icon: _isCheckingPhpUpdates
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(_isCheckingPhpUpdates ? 'Memeriksa...' : 'Periksa Pembaruan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cardHover,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Version Cards Grid / List
          ...versions.map((ver) {
            final updateInfo = updates.where((u) => u.versionKey == ver.versionKey).firstOrNull;
            final isInstalled = ver.isInstalled;
            final hasUpdate = updateInfo?.hasUpdate ?? false;
            final latestVer = updateInfo?.latestVersion ?? ver.exactVersion;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isInstalled
                        ? (hasUpdate ? AppTheme.accentCyan.withOpacity(0.6) : AppTheme.borderDark)
                        : AppTheme.borderDark.withOpacity(0.5),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      // Status Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isInstalled
                              ? AppTheme.accentGreen.withOpacity(0.12)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isInstalled ? Icons.check_circle_rounded : Icons.cloud_download_outlined,
                          color: isInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Version Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  ver.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isInstalled
                                        ? AppTheme.accentGreen.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isInstalled ? 'v${ver.exactVersion}' : 'Tersedia v$latestVer',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                                      fontFamily: 'Consolas',
                                    ),
                                  ),
                                ),
                                if (hasUpdate) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentCyan.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      'Update: v$latestVer',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentCyan,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isInstalled
                                  ? 'Terpasang di ${ver.dirPath}'
                                  : 'Belum terpasang di sistem.',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Action Buttons
                      if (isInstalled) ...[
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedVersionKey = ver.versionKey;
                              _loadCurrentIniValues();
                            });
                            _tabController.animateTo(1); // Jump to ini editor
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentCyan,
                            side: const BorderSide(color: AppTheme.accentCyan),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Edit php.ini'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          tooltip: 'Hapus PHP ${ver.versionKey}',
                          color: AppTheme.accentRed,
                          onPressed: () => _uninstallPhpVersion(ver.versionKey),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: () => _installPhpVersion(ver.versionKey),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: Text('Pasang PHP ${ver.versionKey}'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // TAB 2: IN-APP PHP.INI DIRECTIVES EDITOR
  Widget _buildIniEditorTab() {
    final versions = PhpManager.instance.getVersions();
    final installedVersions = versions.where((v) => v.isInstalled).toList();

    if (installedVersions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warning_amber_rounded, size: 48, color: AppTheme.accentAmber),
            SizedBox(height: 12),
            Text('Belum ada versi PHP yang terpasang', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Silakan pasang salah satu versi PHP terlebih dahulu di tab sebelah.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    final current = versions.where((v) => v.versionKey == _selectedVersionKey).firstOrNull ?? installedVersions.first;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Selector & Notepad Button Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(Icons.settings_suggest_rounded, color: AppTheme.accentCyan, size: 22),
                    const SizedBox(width: 12),
                    const Text('Versi PHP Target:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                    const SizedBox(width: 14),

                    // Version Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: installedVersions.any((v) => v.versionKey == _selectedVersionKey)
                              ? _selectedVersionKey
                              : installedVersions.first.versionKey,
                          dropdownColor: AppTheme.cardDark,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          items: installedVersions.map((v) {
                            return DropdownMenuItem(
                              value: v.versionKey,
                              child: Text('${v.name} (v${v.exactVersion})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedVersionKey = val;
                                _loadCurrentIniValues();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Notepad Button
                    OutlinedButton.icon(
                      onPressed: () => _openInNotepad(current.phpIni),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Buka di Notepad'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppTheme.borderDark),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Directive Input Cards
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppTheme.borderDark),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.tune_rounded, size: 18, color: AppTheme.accentGreen),
                        SizedBox(width: 8),
                        Text(
                          'Direktif Utama php.ini',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Inputs Row 1: memory_limit, upload_max_filesize, post_max_size
                    Row(
                      children: [
                        Expanded(
                          child: _buildDirectiveInput(
                            label: 'memory_limit',
                            desc: 'Batas memori skrip (cth: 512M)',
                            controller: _memoryLimitCtrl,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildDirectiveInput(
                            label: 'upload_max_filesize',
                            desc: 'Batas ukuran file upload (cth: 128M)',
                            controller: _uploadMaxCtrl,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildDirectiveInput(
                            label: 'post_max_size',
                            desc: 'Batas total payload POST (cth: 128M)',
                            controller: _postMaxCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Inputs Row 2: max_execution_time, max_input_vars, timezone
                    Row(
                      children: [
                        Expanded(
                          child: _buildDirectiveInput(
                            label: 'max_execution_time',
                            desc: 'Batas waktu eksekusi skrip (detik)',
                            controller: _maxExecTimeCtrl,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildDirectiveInput(
                            label: 'max_input_vars',
                            desc: 'Batas jumlah variabel input form',
                            controller: _maxInputVarsCtrl,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildDirectiveInput(
                            label: 'date.timezone',
                            desc: 'Zona waktu (cth: Asia/Jakarta)',
                            controller: _timezoneCtrl,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Inputs Row 3: cgi.fix_pathinfo, display_errors
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('cgi.fix_pathinfo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Consolas')),
                              const SizedBox(height: 2),
                              const Text('Normalisasi pathinfo untuk routing framework', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgDark,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderDark),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _fixPathinfo,
                                    dropdownColor: AppTheme.cardDark,
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: '1', child: Text('1 (Aktif)')),
                                      DropdownMenuItem(value: '0', child: Text('0 (Nonaktif)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _fixPathinfo = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('display_errors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Consolas')),
                              const SizedBox(height: 2),
                              const Text('Output error ke HTTP response', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgDark,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.borderDark),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _displayErrors,
                                    dropdownColor: AppTheme.cardDark,
                                    isExpanded: true,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(value: 'On', child: Text('On (Development)')),
                                      DropdownMenuItem(value: 'Off', child: Text('Off (Production)')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setState(() => _displayErrors = val);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveIniValues,
                        icon: _isSaving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Konfigurasi (${current.name})'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectiveInput({
    required String label,
    required String desc,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Consolas'),
        ),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Consolas'),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.bgDark,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      ],
    );
  }
}
