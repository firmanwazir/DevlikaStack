import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../services/server_controller.dart';
import '../services/config_service.dart';
import '../services/version_checker_service.dart';
import '../theme/app_theme.dart';
import '../widgets/port_settings_dialog.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (VersionCheckerService.instance.mariaDbInfo == null) {
        VersionCheckerService.instance.checkMariaDb(checkOnline: false);
      }
    });
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);
    await VersionCheckerService.instance.checkMariaDb(checkOnline: true);
    if (mounted) {
      setState(() => _isCheckingUpdate = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pemeriksaan versi MariaDB selesai.'),
          backgroundColor: AppTheme.cardDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppTheme.borderDark),
          ),
        ),
      );
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin ke clipboard.'),
        backgroundColor: AppTheme.cardDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
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
        SnackBar(
          content: const Text('File my.ini belum dibuat atau belum ada.'),
          backgroundColor: AppTheme.cardDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppTheme.borderDark),
          ),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Service Status Module
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.storage_outlined,
                          color: controller.isMariaDbRunning ? AppTheme.accentGreen : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'MariaDB Database Server',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: controller.isMariaDbRunning
                                      ? AppTheme.accentGreen.withOpacity(0.08)
                                      : AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: controller.isMariaDbRunning
                                        ? AppTheme.accentGreen.withOpacity(0.3)
                                        : AppTheme.borderDark,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: controller.isMariaDbRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      controller.isMariaDbRunning ? 'RUNNING' : 'STOPPED',
                                      style: TextStyle(
                                        fontFamily: AppTheme.monoFont,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: controller.isMariaDbRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            controller.isMariaDbRunning
                                ? 'Mendengarkan di 127.0.0.1:${controller.mariaDbPort} • InnoDB Storage Engine aktif'
                                : (db.isInstalled ? 'Daemon database sedang nonaktif.' : 'MariaDB binary belum terpasang.'),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
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
                        size: 16,
                      ),
                      label: Text(
                        !db.isInstalled
                            ? 'Pasang'
                            : (controller.isMariaDbRunning ? 'Stop MariaDB' : 'Start MariaDB'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: controller.isMariaDbRunning
                            ? AppTheme.accentRed.withOpacity(0.15)
                            : AppTheme.accentGreen,
                        foregroundColor: controller.isMariaDbRunning ? AppTheme.accentRed : Colors.black,
                        side: controller.isMariaDbRunning
                            ? BorderSide(color: AppTheme.accentRed.withOpacity(0.3))
                            : BorderSide.none,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Credentials & Version Detection (Side by Side)
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
                            const SizedBox(width: 14),
                            Expanded(flex: 5, child: rightCard),
                          ],
                        )
                      : Column(
                          children: [
                            leftCard,
                            const SizedBox(height: 14),
                            rightCard,
                          ],
                        );
                },
              ),

              const SizedBox(height: 14),

              // 3. Quick Action Buttons Toolbar
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
                      'Peralatan Database',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.openPhpMyAdmin(),
                            icon: const Icon(Icons.table_chart_outlined, size: 15),
                            label: const Text('Buka phpMyAdmin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: const BorderSide(color: AppTheme.borderDark),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (widget.onNavigate != null) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => widget.onNavigate!(5), // Go to SQL Importer View
                              icon: const Icon(Icons.flash_on_rounded, size: 15, color: AppTheme.accentIndigo),
                              label: const Text('SQL Turbo Importer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side: const BorderSide(color: AppTheme.borderDark),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        OutlinedButton.icon(
                          onPressed: _openMyIni,
                          icon: const Icon(Icons.tune_rounded, size: 15),
                          label: const Text('Edit my.ini', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(color: AppTheme.borderDark),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => controller.openFolder(config.mariaDbDataDir),
                          icon: const Icon(Icons.folder_open_outlined, size: 15),
                          label: const Text('Folder Data', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: const BorderSide(color: AppTheme.borderDark),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCredentialsCard(ConfigService config) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.key_outlined, size: 15, color: AppTheme.textSecondary),
              SizedBox(width: 8),
              Text(
                'Parameter Koneksi',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCopyableRow('Host', '127.0.0.1 (localhost)', '127.0.0.1'),
          const Divider(height: 14, color: AppTheme.borderDark),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCopyableRow('Port', '${ServerController.instance.mariaDbPort}', '${ServerController.instance.mariaDbPort}'),
              InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => const PortSettingsDialog(),
                ),
                child: const Text(
                  'Ubah Port',
                  style: TextStyle(
                    color: AppTheme.accentIndigo,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 14, color: AppTheme.borderDark),
          _buildCopyableRow('Username', 'root', 'root'),
          const Divider(height: 14, color: AppTheme.borderDark),
          _buildCopyableRow('Password', '(kosong / tanpa password)', ''),
          const Divider(height: 14, color: AppTheme.borderDark),
          Row(
            children: [
              const SizedBox(
                width: 110,
                child: Text('Folder Data', style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
              ),
              Expanded(
                child: Text(
                  config.mariaDbDataDir,
                  style: AppTheme.monoStyle(color: AppTheme.textPrimary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: AppTheme.textMuted),
                tooltip: 'Buka Folder Data',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: () => ServerController.instance.openFolder(config.mariaDbDataDir),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard(MariaDbVersionInfo? versionInfo) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.verified_outlined, size: 15, color: AppTheme.textSecondary),
                  SizedBox(width: 8),
                  Text(
                    'Deteksi Versi & mariadb.org',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _isCheckingUpdate ? null : _checkUpdate,
                icon: _isCheckingUpdate
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.textPrimary),
                      )
                    : const Icon(Icons.refresh_rounded, size: 13),
                label: Text(
                  _isCheckingUpdate ? 'Cek...' : 'Cek Update',
                  style: const TextStyle(fontSize: 11),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.borderDark),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
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
                    Container(width: 1, height: 38, color: AppTheme.borderDark),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12),
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
                const Divider(height: 16, color: AppTheme.borderDark),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        versionInfo?.status ?? 'Versi Terkini & Optimal',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Dicek: ${versionInfo != null ? "${versionInfo.lastChecked.hour.toString().padLeft(2, '0')}:${versionInfo.lastChecked.minute.toString().padLeft(2, '0')}" : "Baru saja"}',
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
        Text(title, style: const TextStyle(fontSize: 10.5, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTheme.monoStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildCopyableRow(String label, String displayValue, String copyValue) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
        ),
        Expanded(
          child: Text(
            displayValue,
            style: AppTheme.monoStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (copyValue.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 13, color: AppTheme.textMuted),
            tooltip: 'Salin $label',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
            onPressed: () => _copyToClipboard(copyValue, label),
          ),
      ],
    );
  }
}
