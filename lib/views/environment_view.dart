import 'package:flutter/material.dart';
import '../services/server_controller.dart';
import '../models/component_status.dart';
import '../theme/app_theme.dart';

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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Batch Install Banner
              _buildBatchInstallBanner(context, controller),

              const SizedBox(height: 24),

              const Text(
                'Komponen Runtime',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              const Text(
                'Instalasi komponen runtime portable secara mandiri atau batch.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),

              // Individual Component Cards
              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.php,
                icon: Icons.code_rounded,
                iconColor: AppTheme.accentPurple,
                defaultName: 'PHP FastCGI Runtime',
                details: comp.php.isInstalled
                    ? 'Terpasang: ${comp.php.path}'
                    : 'Eksekusi skrip PHP melalui protokol FastCGI.',
                onInstall: () => controller.installSingleComponent('php'),
              ),

              const SizedBox(height: 16),

              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.mariaDb,
                icon: Icons.storage_rounded,
                iconColor: AppTheme.accentGreen,
                defaultName: 'MariaDB Server (Port 3306)',
                details: comp.mariaDb.isInstalled
                    ? 'Terpasang: ${comp.mariaDb.path}'
                    : 'Database engine relasional lokal berbasis SQL.',
                onInstall: () => controller.installSingleComponent('mariadb'),
              ),

              const SizedBox(height: 16),

              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.phpMyAdmin,
                icon: Icons.table_chart_rounded,
                iconColor: AppTheme.accentAmber,
                defaultName: 'phpMyAdmin',
                details: comp.phpMyAdmin.isInstalled
                    ? 'Terpasang: ${comp.phpMyAdmin.path}'
                    : 'Web interface administrasi basis data MariaDB.',
                onInstall: () => controller.installSingleComponent('phpmyadmin'),
                customAction: comp.phpMyAdmin.isInstalled
                    ? TextButton.icon(
                        onPressed: () => controller.openPhpMyAdmin(),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Buka phpMyAdmin'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.accentCyan),
                      )
                    : null,
              ),

              const SizedBox(height: 16),

              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.nginx,
                icon: Icons.language_rounded,
                iconColor: AppTheme.accentGreen,
                defaultName: 'Nginx Web Server',
                details: comp.nginx.isInstalled
                    ? 'Terpasang: ${comp.nginx.path}'
                    : 'HTTP reverse proxy dan web server berkinerja tinggi.',
                onInstall: () => controller.installSingleComponent('nginx'),
              ),

              const SizedBox(height: 16),

              _buildComponentCard(
                context: context,
                controller: controller,
                item: comp.apache,
                icon: Icons.public_rounded,
                iconColor: AppTheme.accentAmber,
                defaultName: 'Apache HTTPD Server',
                details: comp.apache.isInstalled
                    ? 'Terpasang: ${comp.apache.path}'
                    : 'HTTP server modular dengan evaluasi file .htaccess.',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentBlue.withOpacity(0.15),
            AppTheme.accentPurple.withOpacity(0.12),
          ],
        ),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(14),
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
                      'Instalasi Batch Komponen',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comp.isAllInstalled
                          ? 'Semua komponen runtime dasar telah terpasang.'
                          : 'Unduh dan pasang PHP, MariaDB, serta phpMyAdmin secara otomatis.',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  comp.isAllInstalled ? 'Pasang Ulang Semua' : 'Pasang Semua Komponen',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          if (isBatch) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: controller.batchInstallProgress,
                backgroundColor: AppTheme.bgDark,
                valueColor: const AlwaysStoppedAnimation(AppTheme.accentCyan),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.batchInstallMessage,
              style: const TextStyle(fontSize: 11, color: AppTheme.accentCyan, fontFamily: 'Consolas'),
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
    required Color iconColor,
    required String defaultName,
    required String details,
    required VoidCallback onInstall,
    Widget? customAction,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: item.isInstalled
                                  ? AppTheme.accentGreen.withOpacity(0.12)
                                  : AppTheme.accentAmber.withOpacity(0.12),
                              border: Border.all(
                                color: item.isInstalled
                                    ? AppTheme.accentGreen.withOpacity(0.3)
                                    : AppTheme.accentAmber.withOpacity(0.3),
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.isInstalled ? 'Terpasang' : 'Belum Terpasang',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
                ElevatedButton.icon(
                  onPressed: item.isInstalling ? null : onInstall,
                  icon: item.isInstalling
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(item.isInstalled ? Icons.refresh : Icons.download, size: 16),
                  label: Text(
                    item.isInstalling
                        ? 'Memasang...'
                        : (item.isInstalled ? 'Pasang Ulang' : 'Pasang'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: item.isInstalled ? AppTheme.cardHover : AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            if (item.isInstalling) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.installProgress,
                  backgroundColor: AppTheme.bgDark,
                  valueColor: AlwaysStoppedAnimation(iconColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.statusMessage,
                style: TextStyle(fontSize: 11, color: iconColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
