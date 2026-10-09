import 'package:flutter/material.dart';
import '../services/server_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/add_host_dialog.dart';
import '../widgets/port_settings_dialog.dart';

class DashboardView extends StatelessWidget {
  final ValueChanged<int> onNavigate;

  const DashboardView({super.key, required this.onNavigate});

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
              // 1. Missing Component Banner (If any)
              if (!comp.isAllInstalled) _buildMissingBanner(context, controller),

              // 2. Core Service Modules Row (Web Server & MariaDB)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 780;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildWebServerModule(context, controller)),
                            const SizedBox(width: 14),
                            Expanded(child: _buildMariaDbModule(context, controller)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildWebServerModule(context, controller),
                            const SizedBox(height: 14),
                            _buildMariaDbModule(context, controller),
                          ],
                        );
                },
              ),

              const SizedBox(height: 14),

              // 3. Runtime & Tools Module Row (PHP & phpMyAdmin)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 780;
                  return isWide
                      ? Row(
                          children: [
                            Expanded(child: _buildPhpModule(context, controller)),
                            const SizedBox(width: 14),
                            Expanded(child: _buildPhpMyAdminModule(context, controller)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildPhpModule(context, controller),
                            const SizedBox(height: 14),
                            _buildPhpMyAdminModule(context, controller),
                          ],
                        );
                },
              ),

              const SizedBox(height: 24),

              // 4. Virtual Hosts Header & Quick List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Virtual Hosts Aktif',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: Text(
                          '${controller.sites.length}',
                          style: const TextStyle(
                            fontFamily: AppTheme.monoFont,
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => onNavigate(1),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: const Text('Kelola Semua'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const AddHostDialog(),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text('Tambah Host'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentIndigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _buildQuickSitesList(context, controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMissingBanner(BuildContext context, ServerController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withOpacity(0.08),
        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.accentAmber, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Beberapa runtime komponen server belum terpasang di sistem.',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => onNavigate(7),
            icon: const Icon(Icons.download_rounded, size: 14),
            label: const Text('Pasang Komponen', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.accentAmber,
              side: BorderSide(color: AppTheme.accentAmber.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebServerModule(BuildContext context, ServerController controller) {
    final isInstalled = controller.components.php.isInstalled;
    final isRunning = controller.isWebRunning;

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
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: const Icon(Icons.hub_rounded, color: AppTheme.textPrimary, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Web Server',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.borderDark),
                            ),
                            child: const Text(
                              'HTTP Engine',
                              style: TextStyle(fontFamily: AppTheme.monoFont, fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Port ${controller.httpPort} (HTTP) • Port ${controller.httpsPort} (HTTPS)',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              controller.isWebToggling
                  ? const SizedBox(
                      width: 36,
                      height: 24,
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGreen),
                        ),
                      ),
                    )
                  : Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isRunning,
                        onChanged: isInstalled ? (val) => controller.toggleWebServer(val) : null,
                        activeColor: AppTheme.accentGreen,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderDark),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRunning ? 'Running on 127.0.0.1:${controller.httpPort}' : 'Stopped',
                    style: TextStyle(
                      fontFamily: AppTheme.monoFont,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => onNavigate(2),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Row(
                    children: const [
                      Text(
                        'Konfigurasi Engine',
                        style: TextStyle(color: AppTheme.accentIndigo, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.accentIndigo),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMariaDbModule(BuildContext context, ServerController controller) {
    final isInstalled = controller.components.mariaDb.isInstalled;
    final isRunning = controller.isMariaDbRunning;

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
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: const Icon(Icons.storage_rounded, color: AppTheme.textPrimary, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'MariaDB Server',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.borderDark),
                            ),
                            child: Text(
                              'MySQL ${controller.mariaDbPort}',
                              style: const TextStyle(fontFamily: AppTheme.monoFont, fontSize: 10, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Loopback 127.0.0.1:${controller.mariaDbPort} • root:none',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              controller.isMariaDbToggling
                  ? const SizedBox(
                      width: 36,
                      height: 24,
                      child: Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentGreen),
                        ),
                      ),
                    )
                  : Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: isRunning,
                        onChanged: isInstalled ? (val) => controller.toggleMariaDb(val) : null,
                        activeColor: AppTheme.accentGreen,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderDark),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isRunning ? 'Running on 127.0.0.1:${controller.mariaDbPort}' : 'Stopped',
                    style: TextStyle(
                      fontFamily: AppTheme.monoFont,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => onNavigate(5),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Text(
                        'SQL Importer',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => onNavigate(4),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        children: const [
                          Text(
                            'Kelola DB',
                            style: TextStyle(color: AppTheme.accentIndigo, fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.accentIndigo),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhpModule(BuildContext context, ServerController controller) {
    final php = controller.components.php;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: const Icon(Icons.code_rounded, color: AppTheme.textSecondary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PHP Environment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 1),
                Text(
                  php.isInstalled ? php.version : 'Belum Terpasang',
                  style: TextStyle(
                    fontFamily: AppTheme.monoFont,
                    color: php.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => onNavigate(3),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              backgroundColor: AppTheme.surfaceSubtle,
              side: const BorderSide(color: AppTheme.borderDark),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Detail', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhpMyAdminModule(BuildContext context, ServerController controller) {
    final pma = controller.components.phpMyAdmin;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: const Icon(Icons.table_view_rounded, color: AppTheme.textSecondary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('phpMyAdmin', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 1),
                Text(
                  pma.isInstalled ? 'Siap digunakan' : 'Belum Terpasang',
                  style: TextStyle(
                    color: pma.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: pma.isInstalled
                ? () => controller.openPhpMyAdmin()
                : () => onNavigate(7),
            style: ElevatedButton.styleFrom(
              backgroundColor: pma.isInstalled ? AppTheme.cardHover : AppTheme.surfaceSubtle,
              foregroundColor: AppTheme.textPrimary,
              side: const BorderSide(color: AppTheme.borderDark),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
            ),
            child: Text(pma.isInstalled ? 'Buka GUI' : 'Pasang', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSitesList(BuildContext context, ServerController controller) {
    if (controller.sites.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderDark),
        ),
        padding: const EdgeInsets.all(36),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public_outlined, size: 36, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text(
                'Belum Ada Virtual Host Terdaftar',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tambahkan virtual host untuk mengarahkan domain lokal ke folder proyek Anda.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(context: context, builder: (_) => const AddHostDialog());
                },
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Tambah Virtual Host'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.sites.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderDark),
        itemBuilder: (context, index) {
          final site = controller.sites[index];

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Domain & SSL Badge
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: const Center(
                    child: Icon(Icons.public, color: AppTheme.textSecondary, size: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            site.domain,
                            style: const TextStyle(
                              fontFamily: AppTheme.monoFont,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSubtle,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: AppTheme.borderDark),
                            ),
                            child: Text(
                              site.type == 'proxy' ? 'Proxy :${site.proxyPort}' : site.phpVersion,
                              style: const TextStyle(
                                fontFamily: AppTheme.monoFont,
                                fontSize: 9.5,
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        site.type == 'proxy' ? 'Reverse Proxy ke port ${site.proxyPort}' : site.rootPath,
                        style: const TextStyle(
                          fontFamily: AppTheme.monoFont,
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Fast Action Buttons (Clean & Quiet)
                IconButton(
                  icon: const Icon(Icons.lock_outline_rounded, size: 15, color: AppTheme.accentGreen),
                  tooltip: 'Buka HTTPS (https://${site.domain})',
                  splashRadius: 16,
                  onPressed: () => controller.openUrl('https://${site.domain}'),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 15, color: AppTheme.textSecondary),
                  tooltip: 'Buka HTTP (http://${site.domain})',
                  splashRadius: 16,
                  onPressed: () => controller.openUrl('http://${site.domain}'),
                ),
                if (site.type != 'proxy')
                  IconButton(
                    icon: const Icon(Icons.folder_open_outlined, size: 15, color: AppTheme.textSecondary),
                    tooltip: 'Buka Folder Dokumen',
                    splashRadius: 16,
                    onPressed: () => controller.openFolder(site.rootPath),
                  ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 15, color: AppTheme.textSecondary),
                  tooltip: 'Pengaturan Virtual Host',
                  splashRadius: 16,
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => AddHostDialog(siteToEdit: site),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
