import 'dart:io';
import 'package:flutter/material.dart';
import '../models/php_extension_model.dart';
import '../services/http_server_service.dart';
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

  // Extension Manager State
  String _extensionSearch = '';
  String _selectedCategory = 'Semua';
  String _statusFilter = 'all';
  String _sortBy = 'active_first';
  List<PhpExtensionModel>? _cachedExtensions;
  String? _cachedVersionKey;
  final _searchController = TextEditingController();
  final Map<String, bool> _optimisticToggles = {};
  bool _isApplyingPreset = false;
  bool _isReloadingFastCgi = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initSelectedVersion();

    _tabController.addListener(() {
      if (_tabController.index == 0 && VersionCheckerService.instance.phpUpdates.isEmpty) {
        VersionCheckerService.instance.checkPhp(checkOnline: false);
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
    _searchController.dispose();
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
    _loadExtensions(force: true);
  }

  void _loadExtensions({bool force = false}) {
    if (_selectedVersionKey == null) return;
    if (!force && _cachedExtensions != null && _cachedVersionKey == _selectedVersionKey) {
      return;
    }
    final exts = PhpManager.instance.getExtensions(_selectedVersionKey!);
    setState(() {
      _cachedExtensions = exts;
      _cachedVersionKey = _selectedVersionKey;
    });
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

    final ok = PhpManager.instance.writeDirectives(current.phpIni, directives);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Konfigurasi ${current.name} berhasil disimpan!'
                : 'Gagal menulis berkas php.ini.',
          ),
          backgroundColor: AppTheme.cardDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openInNotepad(String path) {
    if (File(path).existsSync()) {
      Process.run('notepad.exe', [path]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berkas php.ini belum ditemukan.'),
          backgroundColor: AppTheme.cardDark,
        ),
      );
    }
  }

  Future<void> _checkPhpUpdates() async {
    setState(() => _isCheckingPhpUpdates = true);
    await VersionCheckerService.instance.checkPhp(checkOnline: true);
    if (mounted) {
      setState(() => _isCheckingPhpUpdates = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemeriksaan versi PHP selesai.'),
          backgroundColor: AppTheme.cardDark,
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
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.borderDark),
          ),
          title: Row(
            children: [
              const Icon(Icons.download_rounded, color: AppTheme.accentIndigo, size: 18),
              const SizedBox(width: 8),
              Text('Instalasi PHP $versionKey', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: statusNotifier,
                builder: (_, status, __) => Text(status, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
              ),
              const SizedBox(height: 14),
              ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, __) => LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.surfaceSubtle,
                  color: AppTheme.accentIndigo,
                  minHeight: 5,
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
            backgroundColor: AppTheme.cardDark,
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
            backgroundColor: AppTheme.cardDark,
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
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
        title: const Text('Hapus PHP', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        content: Text('Hapus direktori binary dan konfigurasi PHP $versionKey?', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            child: const Text('Hapus', style: TextStyle(fontSize: 12)),
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
            backgroundColor: AppTheme.cardDark,
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Developer Segmented Tab Navigation
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                padding: const EdgeInsets.all(3),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF1E2330),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF2E374A)),
                  ),
                  labelColor: AppTheme.textPrimary,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.inventory_2_outlined, size: 15),
                      text: 'Daftar Versi PHP',
                    ),
                    Tab(
                      icon: Icon(Icons.extension_outlined, size: 15),
                      text: 'Ekstensi PHP (Switch Manager)',
                    ),
                    Tab(
                      icon: Icon(Icons.tune_rounded, size: 15),
                      text: 'Editor php.ini',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVersionsTab(),
                    _buildExtensionsTab(),
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
          // Header Module with Update Checker
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderDark),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: const Icon(Icons.code_rounded, color: AppTheme.textPrimary, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Manajemen Multi-Versi PHP',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Jalankan berbagai versi PHP secara berdampingan. Masing-masing virtual host dapat dipetakan ke versi berbeda.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _isCheckingPhpUpdates ? null : _checkPhpUpdates,
                  icon: _isCheckingPhpUpdates
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(_isCheckingPhpUpdates ? 'Memeriksa...' : 'Cek Pembaruan', style: const TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textPrimary,
                    backgroundColor: AppTheme.surfaceSubtle,
                    side: const BorderSide(color: AppTheme.borderDark),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Version Cards List
          ...versions.map((ver) {
            final updateInfo = updates.where((u) => u.versionKey == ver.versionKey).firstOrNull;
            final isInstalled = ver.isInstalled;
            final hasUpdate = updateInfo?.hasUpdate ?? false;
            final latestVer = updateInfo?.latestVersion ?? ver.exactVersion;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isInstalled ? AppTheme.borderDark : AppTheme.borderSubtle,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Center(
                      child: Text(
                        ver.versionKey,
                        style: const TextStyle(
                          fontFamily: AppTheme.monoFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              ver.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isInstalled ? AppTheme.surfaceSubtle : AppTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: isInstalled ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.borderDark,
                                ),
                              ),
                              child: Text(
                                isInstalled ? 'v${ver.exactVersion}' : 'Tersedia v$latestVer',
                                style: TextStyle(
                                  fontFamily: AppTheme.monoFont,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                                ),
                              ),
                            ),
                            if (hasUpdate) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                                ),
                                child: Text(
                                  'Update: v$latestVer',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.monoFont,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.accentCyan,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isInstalled ? ver.dirPath : 'Belum terpasang di sistem local.',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontFamily: AppTheme.monoFont),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  if (isInstalled) ...[
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedVersionKey = ver.versionKey;
                          _loadCurrentIniValues();
                          _tabController.animateTo(1);
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        backgroundColor: AppTheme.surfaceSubtle,
                        side: const BorderSide(color: AppTheme.borderDark),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('php.ini', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.folder_open_outlined, size: 15, color: AppTheme.textSecondary),
                      tooltip: 'Buka Folder PHP',
                      splashRadius: 15,
                      onPressed: () => ServerController.instance.openFolder(ver.dirPath),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 15, color: AppTheme.accentRed),
                      tooltip: 'Hapus PHP ${ver.versionKey}',
                      splashRadius: 15,
                      onPressed: () => _uninstallPhpVersion(ver.versionKey),
                    ),
                  ] else ...[
                    OutlinedButton.icon(
                      onPressed: () => _installPhpVersion(ver.versionKey),
                      icon: const Icon(Icons.download_rounded, size: 13),
                      label: const Text('Pasang', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        backgroundColor: AppTheme.surfaceSubtle,
                        side: const BorderSide(color: AppTheme.borderDark),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: VISUAL EXTENSION SWITCH MANAGER & PRESETS
  // =========================================================================

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Database':
        return Icons.storage_rounded;
      case 'Web & API':
        return Icons.cloud_sync_rounded;
      case 'Media & File':
        return Icons.photo_library_rounded;
      case 'Security & Crypto':
        return Icons.shield_rounded;
      case 'Framework & Text':
        return Icons.text_fields_rounded;
      case 'Performance & Debug':
        return Icons.speed_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Database':
        return const Color(0xFF38BDF8); // Sky blue
      case 'Web & API':
        return const Color(0xFF2DD4BF); // Teal
      case 'Media & File':
        return const Color(0xFFFBBF24); // Amber
      case 'Security & Crypto':
        return const Color(0xFF4ADE80); // Emerald green
      case 'Framework & Text':
        return const Color(0xFFA78BFA); // Purple
      case 'Performance & Debug':
        return const Color(0xFFFB923C); // Orange
      default:
        return AppTheme.accentIndigo;
    }
  }

  Future<void> _toggleExtension(PhpExtensionModel ext, bool newValue, String versionKey) async {
    // 1. Instant optimistic visual feedback
    setState(() {
      _optimisticToggles[ext.key] = newValue;
    });

    try {
      final ok = await PhpManager.instance.setExtension(
        versionKey: versionKey,
        extensionKey: ext.key,
        enable: newValue,
        reloadFastCgi: true,
      );

      if (mounted) {
        setState(() {
          _optimisticToggles.remove(ext.key);
          if (ok) {
            _cachedExtensions = PhpManager.instance.getExtensions(versionKey);
            _cachedVersionKey = versionKey;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newValue ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: newValue ? AppTheme.accentGreen : AppTheme.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ok
                        ? 'Ekstensi ${ext.name} ${newValue ? 'diaktifkan' : 'dinonaktifkan'}. FastCGI PHP $versionKey dimuat ulang!'
                        : 'Gagal memperbarui ekstensi ${ext.name}.',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.cardDark,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticToggles.remove(ext.key);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: AppTheme.cardDark,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _applyPreset(String presetKey, String presetLabel) async {
    setState(() => _isApplyingPreset = true);
    final ok = await PhpManager.instance.applyPreset(
      versionKey: _selectedVersionKey,
      presetName: presetKey,
      reloadFastCgi: true,
    );
    if (mounted) {
      setState(() {
        _isApplyingPreset = false;
        if (ok && _selectedVersionKey != null) {
          _cachedExtensions = PhpManager.instance.getExtensions(_selectedVersionKey!);
          _cachedVersionKey = _selectedVersionKey;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.accentAmber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ok
                      ? 'Preset $presetLabel berhasil diterapkan ke PHP $_selectedVersionKey! FastCGI dimuat ulang.'
                      : 'Gagal menerapkan preset $presetLabel.',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.cardDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _reloadFastCgi(String versionKey) async {
    setState(() => _isReloadingFastCgi = true);
    await HttpServerService.instance.restartFastCgiPool(versionKey, debounce: false);
    if (mounted) {
      setState(() => _isReloadingFastCgi = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.sync_rounded, color: AppTheme.accentCyan, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Worker pool FastCGI PHP $versionKey berhasil dimuat ulang!',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.cardDark,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildExtensionsTab() {
    final versions = PhpManager.instance.getVersions();
    final installedVersions = versions.where((v) => v.isInstalled).toList();

    if (installedVersions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.extension_off_rounded, size: 36, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Belum ada versi PHP yang terpasang', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Silakan pasang salah satu versi PHP terlebih dahulu pada tab "Daftar Versi PHP".', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    final current = versions.where((v) => v.versionKey == _selectedVersionKey).firstOrNull ?? installedVersions.first;
    if (_cachedExtensions == null || _cachedVersionKey != current.versionKey) {
      _cachedExtensions = PhpManager.instance.getExtensions(current.versionKey);
      _cachedVersionKey = current.versionKey;
    }
    final allExtensions = _cachedExtensions!;
    final activeCount = allExtensions.where((e) => _optimisticToggles[e.key] ?? e.isEnabled).length;

    // Filter categories
    final categories = ['Semua', 'Database', 'Web & API', 'Media & File', 'Security & Crypto', 'Framework & Text', 'Performance & Debug'];
    if (allExtensions.any((e) => e.category == 'Ekstensi Ekstra')) {
      categories.add('Ekstensi Ekstra');
    }

    // Apply in-memory filtering
    var filteredExtensions = List<PhpExtensionModel>.from(allExtensions);
    if (_selectedCategory != 'Semua') {
      filteredExtensions = filteredExtensions.where((e) => e.category == _selectedCategory).toList();
    }
    if (_statusFilter == 'active') {
      filteredExtensions = filteredExtensions.where((e) => _optimisticToggles[e.key] ?? e.isEnabled).toList();
    } else if (_statusFilter == 'inactive') {
      filteredExtensions = filteredExtensions.where((e) => !(_optimisticToggles[e.key] ?? e.isEnabled)).toList();
    }
    if (_extensionSearch.isNotEmpty) {
      final q = _extensionSearch.toLowerCase();
      filteredExtensions = filteredExtensions.where((e) =>
        e.key.toLowerCase().contains(q) ||
        e.name.toLowerCase().contains(q) ||
        e.description.toLowerCase().contains(q)
      ).toList();
    }

    // Sortir
    filteredExtensions.sort((a, b) {
      final aActive = _optimisticToggles[a.key] ?? a.isEnabled;
      final bActive = _optimisticToggles[b.key] ?? b.isEnabled;

      switch (_sortBy) {
        case 'active_first':
          if (aActive != bActive) return aActive ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'name_asc':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'name_desc':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case 'category':
          final catComp = a.category.compareTo(b.category);
          if (catComp != 0) return catComp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        default:
          if (aActive != bActive) return aActive ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Toolbar: Version Selector + Presets Bar + FastCGI Reload
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderDark),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Versi PHP:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(width: 10),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: installedVersions.any((v) => v.versionKey == _selectedVersionKey)
                            ? _selectedVersionKey
                            : installedVersions.first.versionKey,
                        dropdownColor: AppTheme.cardDark,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: AppTheme.monoFont),
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
                              _cachedExtensions = PhpManager.instance.getExtensions(val);
                              _cachedVersionKey = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$activeCount / ${allExtensions.length} Ekstensi Aktif',
                          style: const TextStyle(
                            fontFamily: AppTheme.monoFont,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Reload FastCGI Button
                  OutlinedButton.icon(
                    onPressed: _isReloadingFastCgi ? null : () => _reloadFastCgi(current.versionKey),
                    icon: _isReloadingFastCgi
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.sync_rounded, size: 14),
                    label: Text(_isReloadingFastCgi ? 'Memuat Ulang...' : 'Reload FastCGI', style: const TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      backgroundColor: AppTheme.surfaceSubtle,
                      side: const BorderSide(color: AppTheme.borderDark),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Presets Row
              Row(
                children: [
                  const Text('Preset Cepat:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 10),
                  _buildPresetButton(
                    label: 'Laravel',
                    icon: Icons.rocket_launch_rounded,
                    color: const Color(0xFFF43F5E),
                    onPressed: () => _applyPreset('laravel', 'Laravel'),
                  ),
                  const SizedBox(width: 8),
                  _buildPresetButton(
                    label: 'WordPress',
                    icon: Icons.language_rounded,
                    color: const Color(0xFF38BDF8),
                    onPressed: () => _applyPreset('wordpress', 'WordPress'),
                  ),
                  const SizedBox(width: 8),
                  _buildPresetButton(
                    label: 'Minimal',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFFFBBF24),
                    onPressed: () => _applyPreset('minimal', 'Minimal'),
                  ),
                  const Spacer(),
                  Text(
                    'Perubahan langsung otomatis hot-reload FastCGI tanpa restart server',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted.withOpacity(0.8)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Search & Filter Controls (Tier 1: Responsive Search + Status Filter + Sort Dropdown + Reset)
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;

            final searchWidget = Container(
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderDark),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5),
                      decoration: const InputDecoration(
                        hintText: 'Cari ekstensi (contoh: curl, intl, pdo, gd, redis)...',
                        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() => _extensionSearch = val.trim());
                      },
                    ),
                  ),
                  if (_extensionSearch.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _extensionSearch = '');
                      },
                      child: const Icon(Icons.close_rounded, size: 15, color: AppTheme.textMuted),
                    ),
                ],
              ),
            );

            final statusWidget = Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _statusFilter == 'active'
                        ? Icons.check_circle_rounded
                        : _statusFilter == 'inactive'
                            ? Icons.remove_circle_outline_rounded
                            : Icons.tune_rounded,
                    size: 14,
                    color: _statusFilter == 'active'
                        ? AppTheme.accentGreen
                        : _statusFilter == 'inactive'
                            ? AppTheme.accentAmber
                            : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      dropdownColor: AppTheme.cardDark,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Semua Status')),
                        DropdownMenuItem(value: 'active', child: Text('Hanya Aktif')),
                        DropdownMenuItem(value: 'inactive', child: Text('Hanya Nonaktif')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _statusFilter = val);
                      },
                    ),
                  ),
                ],
              ),
            );

            final sortWidget = Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, size: 15, color: AppTheme.accentIndigo),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      dropdownColor: AppTheme.cardDark,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500),
                      items: const [
                        DropdownMenuItem(value: 'active_first', child: Text('Sortir: Aktif di Atas')),
                        DropdownMenuItem(value: 'name_asc', child: Text('Sortir: Nama (A - Z)')),
                        DropdownMenuItem(value: 'name_desc', child: Text('Sortir: Nama (Z - A)')),
                        DropdownMenuItem(value: 'category', child: Text('Sortir: Kategori')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _sortBy = val);
                      },
                    ),
                  ),
                ],
              ),
            );

            final isFiltered = _extensionSearch.isNotEmpty || _selectedCategory != 'Semua' || _statusFilter != 'all';

            final resetBtn = isFiltered
                ? Tooltip(
                    message: 'Reset semua filter dan pencarian',
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _extensionSearch = '';
                          _selectedCategory = 'Semua';
                          _statusFilter = 'all';
                        });
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentAmber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.restart_alt_rounded, size: 15, color: AppTheme.accentAmber),
                            SizedBox(width: 4),
                            Text('Reset Filter', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.accentAmber)),
                          ],
                        ),
                      ),
                    ),
                  )
                : null;

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchWidget,
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: statusWidget),
                      const SizedBox(width: 8),
                      Expanded(child: sortWidget),
                      if (resetBtn != null) ...[
                        const SizedBox(width: 8),
                        resetBtn,
                      ],
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: searchWidget),
                const SizedBox(width: 10),
                statusWidget,
                const SizedBox(width: 10),
                sortWidget,
                if (resetBtn != null) ...[
                  const SizedBox(width: 10),
                  resetBtn,
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 10),

        // Category Chips Bar (Tier 2: Full-width Wrap, responsive cards)
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.cardDark.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.borderDark),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.category_outlined, size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  const Text(
                    'Kategori Ekstensi:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    'Menampilkan ${filteredExtensions.length} dari ${allExtensions.length} ekstensi',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontFamily: AppTheme.monoFont),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  final catColor = cat == 'Semua' ? const Color(0xFF6366F1) : _getCategoryColor(cat);
                  final catIcon = cat == 'Semua' ? Icons.apps_rounded : _getCategoryIcon(cat);

                  final totalCount = cat == 'Semua'
                      ? allExtensions.length
                      : allExtensions.where((e) => e.category == cat).length;
                  final activeInCat = cat == 'Semua'
                      ? allExtensions.where((e) => _optimisticToggles[e.key] ?? e.isEnabled).length
                      : allExtensions.where((e) => e.category == cat && (_optimisticToggles[e.key] ?? e.isEnabled)).length;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSelected ? catColor.withOpacity(0.18) : AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? catColor : AppTheme.borderDark,
                            width: isSelected ? 1.4 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: catColor.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              catIcon,
                              size: 13,
                              color: isSelected ? catColor : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? catColor.withOpacity(0.28)
                                    : (activeInCat > 0 ? AppTheme.accentGreen.withOpacity(0.12) : AppTheme.cardDark),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected
                                      ? catColor.withOpacity(0.4)
                                      : (activeInCat > 0 ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.borderDark),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                cat == 'Semua'
                                    ? '$activeInCat/$totalCount'
                                    : (activeInCat > 0 ? '$activeInCat/$totalCount' : '$totalCount'),
                                style: TextStyle(
                                  fontFamily: AppTheme.monoFont,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? catColor
                                      : (activeInCat > 0 ? AppTheme.accentGreen : AppTheme.textMuted),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Extensions List
        Expanded(
          child: filteredExtensions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 36, color: AppTheme.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'Tidak ada ekstensi yang cocok dengan filter yang dipilih',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _extensionSearch.isNotEmpty
                            ? 'Pencarian: "$_extensionSearch"'
                            : 'Kategori: $_selectedCategory • Status: ${_statusFilter == "active" ? "Aktif" : _statusFilter == "inactive" ? "Nonaktif" : "Semua"}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _extensionSearch = '';
                            _selectedCategory = 'Semua';
                            _statusFilter = 'all';
                          });
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 14),
                        label: const Text('Reset Semua Filter', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(color: AppTheme.borderDark),
                          backgroundColor: AppTheme.cardDark,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredExtensions.length,
                  itemBuilder: (context, index) {
                    final ext = filteredExtensions[index];
                    return _buildExtensionCard(ext, current.versionKey);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPresetButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _isApplyingPreset ? null : onPressed,
      icon: Icon(icon, size: 13, color: color),
      label: Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      style: OutlinedButton.styleFrom(
        backgroundColor: color.withOpacity(0.08),
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildExtensionCard(PhpExtensionModel ext, String versionKey) {
    final catColor = _getCategoryColor(ext.category);
    final isEnabled = _optimisticToggles[ext.key] ?? ext.isEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEnabled ? AppTheme.borderDark : AppTheme.borderSubtle,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          // Category Avatar Icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: catColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: catColor.withOpacity(0.25)),
            ),
            child: Icon(_getCategoryIcon(ext.category), color: catColor, size: 17),
          ),
          const SizedBox(width: 12),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ext.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    // Key pill badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: Text(
                        ext.key,
                        style: const TextStyle(
                          fontFamily: AppTheme.monoFont,
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                    if (ext.isZend) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
                        ),
                        child: const Text(
                          'ZEND',
                          style: TextStyle(
                            fontFamily: AppTheme.monoFont,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF97316),
                          ),
                        ),
                      ),
                    ],
                    if (!ext.isAvailableOnDisk) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppTheme.accentAmber.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.warning_amber_rounded, size: 10, color: AppTheme.accentAmber),
                            SizedBox(width: 3),
                            Text(
                              'DLL Tidak Ditemukan',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentAmber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  ext.description,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Switch Toggle
          Switch.adaptive(
            value: isEnabled,
            activeColor: AppTheme.accentGreen,
            activeTrackColor: AppTheme.accentGreen.withOpacity(0.3),
            inactiveThumbColor: AppTheme.textMuted,
            inactiveTrackColor: AppTheme.surfaceSubtle,
            onChanged: (val) => _toggleExtension(ext, val, versionKey),
          ),
        ],
      ),
    );
  }

  // TAB 3: INI EDITOR
  Widget _buildIniEditorTab() {
    final versions = PhpManager.instance.getVersions();
    final installedVersions = versions.where((v) => v.isInstalled).toList();

    if (installedVersions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inventory_2_outlined, size: 36, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Belum ada versi PHP yang terpasang', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Silakan pasang salah satu versi PHP terlebih dahulu pada tab sebelah.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
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
            // Top Selector Toolbar
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderDark),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('Versi PHP:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                  const SizedBox(width: 12),

                  Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: installedVersions.any((v) => v.versionKey == _selectedVersionKey)
                            ? _selectedVersionKey
                            : installedVersions.first.versionKey,
                        dropdownColor: AppTheme.cardDark,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: AppTheme.monoFont),
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

                  OutlinedButton.icon(
                    onPressed: () => _openInNotepad(current.phpIni),
                    icon: const Icon(Icons.edit_note_rounded, size: 15),
                    label: const Text('Buka di Notepad', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      backgroundColor: AppTheme.surfaceSubtle,
                      side: const BorderSide(color: AppTheme.borderDark),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Directives Input Module
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderDark),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Direktif Utama php.ini',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 14),

                  // Row 1
                  Row(
                    children: [
                      Expanded(
                        child: _buildDirectiveInput(
                          label: 'memory_limit',
                          desc: 'Batas memori skrip (cth: 512M)',
                          controller: _memoryLimitCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDirectiveInput(
                          label: 'upload_max_filesize',
                          desc: 'Batas ukuran file upload (cth: 128M)',
                          controller: _uploadMaxCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDirectiveInput(
                          label: 'post_max_size',
                          desc: 'Batas total payload POST (cth: 128M)',
                          controller: _postMaxCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Row 2
                  Row(
                    children: [
                      Expanded(
                        child: _buildDirectiveInput(
                          label: 'max_execution_time',
                          desc: 'Batas waktu eksekusi skrip (detik)',
                          controller: _maxExecTimeCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDirectiveInput(
                          label: 'max_input_vars',
                          desc: 'Batas jumlah variabel input form',
                          controller: _maxInputVarsCtrl,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDirectiveInput(
                          label: 'date.timezone',
                          desc: 'Zona waktu PHP (cth: Asia/Jakarta)',
                          controller: _timezoneCtrl,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Row 3
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('cgi.fix_pathinfo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: AppTheme.monoFont)),
                            const SizedBox(height: 2),
                            const Text('Normalisasi pathinfo untuk routing framework', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
                                  value: _fixPathinfo,
                                  dropdownColor: AppTheme.cardDark,
                                  isExpanded: true,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: AppTheme.monoFont),
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('display_errors', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: AppTheme.monoFont)),
                            const SizedBox(height: 2),
                            const Text('Output error ke response browser', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
                                  value: _displayErrors,
                                  dropdownColor: AppTheme.cardDark,
                                  isExpanded: true,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontFamily: AppTheme.monoFont),
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
                  const SizedBox(height: 18),

                  // Save Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveIniValues,
                      icon: _isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 15, color: Colors.white),
                      label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Konfigurasi (${current.name})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontFamily: AppTheme.monoFont),
        ),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: TextFormField(
            controller: controller,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontFamily: AppTheme.monoFont),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppTheme.surfaceSubtle,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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
      ],
    );
  }
}
