import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../services/server_controller.dart';
import '../services/config_service.dart';
import '../services/version_checker_service.dart';
import '../theme/app_theme.dart';

class MariaDbView extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const MariaDbView({super.key, this.onNavigate});

  @override
  State<MariaDbView> createState() => _MariaDbViewState();
}

class _MariaDbViewState extends State<MariaDbView> {
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    // Auto-detect version on view load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (VersionCheckerService.instance.mariaDbInfo == null) {
        VersionCheckerService.instance.checkMariaDb();
      }
    });
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);
    await VersionCheckerService.instance.checkMariaDb();
    if (mounted) {
      setState(() => _isCheckingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pemeriksaan versi MariaDB selesai!'),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard.'),
        backgroundColor: AppTheme.accentBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openMyIni() {
    final myIni = p.join(ConfigService.instance.mariaDbDir, 'my.ini');
    if (File(myIni).existsSync()) {
      Process.run('notepad.exe', [myIni]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File my.ini belum dibuat atau belum ada.'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
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
        final controller = ServerController.instance;
        final db = controller.components.mariaDb;
        final config = ConfigService.instance;
        final versionInfo = VersionCheckerService.instance.mariaDbInfo;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Service Status Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppTheme.borderDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: controller.isMariaDbRunning
                              ? AppTheme.accentGreen.withOpacity(0.15)
                              : AppTheme.cardHover,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: controller.isMariaDbRunning
                                ? AppTheme.accentGreen.withOpacity(0.3)
                                : AppTheme.borderDark,
                          ),
                        ),
                        child: Icon(
                          Icons.storage_rounded,
                          color: controller.isMariaDbRunning ? AppTheme.accentGreen : AppTheme.textSecondary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'MariaDB Database Server',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: controller.isMariaDbRunning
                                        ? AppTheme.accentGreen.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: controller.isMariaDbRunning
                                          ? AppTheme.accentGreen.withOpacity(0.4)
                                          : Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    controller.isMariaDbRunning ? 'BERJALAN' : 'BERHENTI',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: controller.isMariaDbRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              controller.isMariaDbRunning
                                  ? 'Berjalan di Port 3306 (127.0.0.1) • Siap menerima koneksi'
                                  : (db.isInstalled ? 'Server tidak aktif.' : 'MariaDB belum terpasang.'),
                              style: TextStyle(
                                color: controller.isMariaDbRunning ? AppTheme.accentGreen : AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: db.isInstalled
                            ? () => controller.toggleMariaDb(!controller.isMariaDbRunning)
                            : () => controller.installSingleComponent('mariadb'),
                        icon: Icon(
                          controller.isMariaDbRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          size: 18,
                        ),
                        label: Text(
                          !db.isInstalled
                              ? 'Pasang'
                              : (controller.isMariaDbRunning ? 'Stop Server' : 'Start Server'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: controller.isMariaDbRunning ? AppTheme.accentRed : AppTheme.accentGreen,
                          foregroundColor: controller.isMariaDbRunning ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 2. Side-by-side 2-Column: Credentials (Left) & Version Detection (Right)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 750;
                  final leftCard = _buildCredentialsCard(config);
                  final rightCard = _buildVersionCard(versionInfo);

                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: leftCard),
                            const SizedBox(width: 18),
                            Expanded(flex: 5, child: rightCard),
                          ],
                        )
                      : Column(
                          children: [
                            leftCard,
                            const SizedBox(height: 18),
                            rightCard,
                          ],
                        );
                },
              ),

              const SizedBox(height: 20),

              // 3. Quick Action Buttons Toolbar (phpMyAdmin, Turbo Importer, my.ini, Folder Data)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppTheme.borderDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.dashboard_customize_rounded, size: 18, color: AppTheme.accentCyan),
                          SizedBox(width: 8),
                          Text(
                            'Alat Database',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => controller.openPhpMyAdmin(),
                              icon: const Icon(Icons.table_chart_rounded, size: 18),
                              label: const Text('Buka phpMyAdmin', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (widget.onNavigate != null) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => widget.onNavigate!(5), // Go to Turbo Importer View
                                icon: const Icon(Icons.bolt_rounded, size: 20, color: Colors.amber),
                                label: const Text('SQL Importer', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.cardHover,
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: AppTheme.accentAmber.withOpacity(0.5)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          ElevatedButton.icon(
                            onPressed: _openMyIni,
                            icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                            label: const Text('Edit my.ini'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cardHover,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: const Icon(Icons.folder_open_rounded, size: 20, color: AppTheme.accentCyan),
                            tooltip: 'Folder Data MariaDB',
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.cardHover,
                              padding: const EdgeInsets.all(14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => controller.openFolder(config.mariaDbDataDir),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCredentialsCard(ConfigService config) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.key_rounded, size: 18, color: AppTheme.accentAmber),
                SizedBox(width: 8),
                Text(
                  'Parameter Koneksi',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildCopyableRow('Host', '127.0.0.1 (localhost)', '127.0.0.1'),
            const Divider(height: 16, color: AppTheme.borderDark),
            _buildCopyableRow('Port', '3306', '3306'),
            const Divider(height: 16, color: AppTheme.borderDark),
            _buildCopyableRow('Username', 'root', 'root'),
            const Divider(height: 16, color: AppTheme.borderDark),
            _buildCopyableRow('Password', '(tanpa password)', ''),
            const Divider(height: 16, color: AppTheme.borderDark),
            Row(
              children: [
                const SizedBox(
                  width: 120,
                  child: Text('Folder Data', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
                Expanded(
                  child: Text(
                    config.mariaDbDataDir,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Consolas'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open_rounded, size: 16, color: AppTheme.textSecondary),
                  tooltip: 'Buka Folder Data',
                  onPressed: () => ServerController.instance.openFolder(config.mariaDbDataDir),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCard(MariaDbVersionInfo? versionInfo) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.verified_rounded, size: 18, color: AppTheme.accentCyan),
                    SizedBox(width: 8),
                    Text(
                      'Deteksi Versi & mariadb.org',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isCheckingUpdate ? null : _checkUpdate,
                  icon: _isCheckingUpdate
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(_isCheckingUpdate ? 'Memeriksa...' : 'Cek Update', style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cardHover,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildVersionColumn(
                          title: 'Versi Terpasang',
                          value: versionInfo?.installedVersion ?? 'Mendeteksi...',
                          subtitle: versionInfo?.architecture ?? 'Win64 (AMD64)',
                          isHighlighted: true,
                        ),
                      ),
                      Container(width: 1, height: 42, color: AppTheme.borderDark),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 14),
                          child: _buildVersionColumn(
                            title: 'Versi Stabil Terkini',
                            value: versionInfo?.latestStable ?? 'Memeriksa...',
                            subtitle: 'Resmi mariadb.org',
                            isHighlighted: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppTheme.borderDark),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.accentGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          versionInfo?.status ?? 'Versi Terkini & Optimal',
                          style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Dicek: ${versionInfo != null ? "${versionInfo.lastChecked.hour.toString().padLeft(2, '0')}:${versionInfo.lastChecked.minute.toString().padLeft(2, '0')}" : "Baru saja"}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionColumn({
    required String title,
    required String value,
    required String subtitle,
    required bool isHighlighted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: isHighlighted ? AppTheme.accentCyan : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            fontFamily: 'Consolas',
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildCopyableRow(String label, String displayValue, String copyValue) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            displayValue,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Consolas'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (copyValue.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.textSecondary),
            tooltip: 'Salin $label',
            onPressed: () => _copyToClipboard(copyValue, label),
          ),
      ],
    );
  }
}
