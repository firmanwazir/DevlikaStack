import 'package:flutter/material.dart';
import '../services/server_controller.dart';
import '../models/component_status.dart';
import '../theme/app_theme.dart';
import '../widgets/port_settings_dialog.dart';

class EnvironmentView extends StatelessWidget {
  const EnvironmentView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServerController.instance,
      builder: (context, _) {
        final controller = ServerController.instance;
        final comp = controller.components;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Batch Install Module
              _buildBatchInstallBanner(context, controller),

              const SizedBox(height: 14),

              // Network & Port Configuration Card (XAMPP Coexistence)
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: const Icon(Icons.lan_outlined, size: 20, color: AppTheme.accentIndigo),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Port Jaringan & Pencegahan Konflik (XAMPP / IIS)',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'HTTP: ${controller.httpPort}  •  HTTPS: ${controller.httpsPort}  •  MariaDB: ${controller.mariaDbPort}',
                            style: const TextStyle(fontFamily: AppTheme.monoFont, fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (ctx) => const PortSettingsDialog(),
                      ),
                      icon: const Icon(Icons.tune_rounded, size: 14, color: AppTheme.accentIndigo),
                      label: const Text('Atur Port', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        backgroundColor: AppTheme.surfaceSubtle,
                        side: const BorderSide(color: AppTheme.borderDark),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Daftar Komponen Server',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 3),
              const Text(
                'Kelola dependensi binary portable PHP, MariaDB, web engine, dan alat manajemen.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),

              // 2. Individual Component Modules
              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.php,
                icon: Icons.code_rounded,
                defaultName: 'PHP FastCGI Runtime',
                details: comp.php.isInstalled
                    ? comp.php.path
                    : 'Eksekusi runtime skrip PHP via FastCGI pool.',
                onInstall: () => controller.installSingleComponent('php'),
              ),

              const SizedBox(height: 10),

              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.mariaDb,
                icon: Icons.storage_rounded,
                defaultName: 'MariaDB Server (Port ${controller.mariaDbPort})',
                details: comp.mariaDb.isInstalled
                    ? comp.mariaDb.path
                    : 'Engine database SQL relasional lokal terisolasi.',
                onInstall: () => controller.installSingleComponent('mariadb'),
              ),

              const SizedBox(height: 10),

              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.phpMyAdmin,
                icon: Icons.table_view_rounded,
                defaultName: 'phpMyAdmin',
                details: comp.phpMyAdmin.isInstalled
                    ? comp.phpMyAdmin.path
                    : 'Antarmuka web untuk administrasi basis data MariaDB.',
                onInstall: () => controller.installSingleComponent('phpmyadmin'),
                customAction: comp.phpMyAdmin.isInstalled
                    ? OutlinedButton.icon(
                        onPressed: () => controller.openPhpMyAdmin(),
                        icon: const Icon(Icons.open_in_new_rounded, size: 13),
                        label: const Text('Buka GUI', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          backgroundColor: AppTheme.surfaceSubtle,
                          side: const BorderSide(color: AppTheme.borderDark),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                    : null,
              ),

              const SizedBox(height: 10),

              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.nginx,
                icon: Icons.hub_rounded,
                defaultName: 'Nginx Web Server',
                details: comp.nginx.isInstalled
                    ? comp.nginx.path
                    : 'Web server event-driven dan reverse proxy kencang.',
                onInstall: () => controller.installSingleComponent('nginx'),
              ),

              const SizedBox(height: 10),

              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.apache,
                icon: Icons.public_rounded,
                defaultName: 'Apache HTTPD Server',
                details: comp.apache.isInstalled
                    ? comp.apache.path
                    : 'HTTP server modular dengan evaluasi berkas .htaccess.',
                onInstall: () => controller.installSingleComponent('apache'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBatchInstallBanner(BuildContext context, ServerController controller) {
    final isBatch = controller.isBatchInstalling;
    final comp = controller.components;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pusat Unduhan Komponen',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comp.isAllInstalled
                          ? 'Semua komponen runtime dasar telah terpasang dengan lengkap di sistem.'
                          : 'Unduh dan pasang PHP, MariaDB, serta phpMyAdmin sekaligus dalam 1 klik.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: isBatch ? null : () => controller.installAllComponents(),
                icon: isBatch
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded, size: 15, color: Colors.white),
                label: Text(
                  comp.isAllInstalled ? 'Pasang Ulang Semua' : 'Pasang Semua Komponen',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentIndigo,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ],
          ),
          if (isBatch) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: controller.batchInstallProgress,
                backgroundColor: AppTheme.surfaceSubtle,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accentIndigo),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              controller.batchInstallMessage,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontFamily: AppTheme.monoFont),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildComponentCard({
    required BuildContext context,
    required ServerController controller,
    required ComponentItem item,
    required IconData icon,
    required String defaultName,
    required String details,
    required VoidCallback onInstall,
    Widget? customAction,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: Icon(icon, color: AppTheme.textPrimary, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: item.isInstalled ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.borderDark,
                            ),
                          ),
                          child: Text(
                            item.isInstalled ? 'Terpasang' : 'Belum Terpasang',
                            style: TextStyle(
                              fontFamily: AppTheme.monoFont,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: item.isInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5, fontFamily: AppTheme.monoFont),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (customAction != null) ...[
                customAction,
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: item.isInstalling ? null : onInstall,
                icon: item.isInstalling
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(item.isInstalled ? Icons.refresh_rounded : Icons.download_rounded, size: 14),
                label: Text(
                  item.isInstalling
                      ? 'Memasang...'
                      : (item.isInstalled ? 'Pasang Ulang' : 'Pasang'),
                  style: const TextStyle(fontSize: 11.5),
                ),
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
          ),
          if (item.isInstalling) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: item.installProgress,
                backgroundColor: AppTheme.surfaceSubtle,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accentIndigo),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              item.statusMessage,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.accentIndigo, fontFamily: AppTheme.monoFont),
            ),
          ],
        ],
      ),
    );
  }
}
