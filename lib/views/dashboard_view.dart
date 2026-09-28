import 'package:flutter/material.dart';
import '../services/server_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/add_host_dialog.dart';

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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Missing Component Warning Banner
              if (!comp.isAllInstalled) _buildMissingBanner(context, controller),

              // Service Cards Row (Web Server & MariaDB)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildWebServerCard(context, controller)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildMariaDbCard(context, controller)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildWebServerCard(context, controller),
                            const SizedBox(height: 16),
                            _buildMariaDbCard(context, controller),
                          ],
                        );
                },
              ),

              const SizedBox(height: 16),

              // Secondary Info Cards Row (PHP Engine & phpMyAdmin)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return isWide
                      ? Row(
                          children: [
                            Expanded(child: _buildPhpInfoCard(context, controller)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildPhpMyAdminCard(context, controller)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildPhpInfoCard(context, controller),
                            const SizedBox(height: 16),
                            _buildPhpMyAdminCard(context, controller),
                          ],
                        );
                },
              ),

              const SizedBox(height: 28),

              // Quick Websites Overview Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Virtual Hosts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${controller.sites.length}',
                          style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => onNavigate(1), // Go to Hosts view
                        icon: const Icon(Icons.list_alt_rounded, size: 16),
                        label: const Text('Lihat Semua'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const AddHostDialog(),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah Host'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildQuickSitesList(context, controller),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMissingBanner(BuildContext context, ServerController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withOpacity(0.12),
        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.accentAmber, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Komponen Runtime Belum Lengkap',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  'Beberapa komponen runtime belum terpasang. Pasang komponen untuk menjalankan layanan.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => onNavigate(7), // Go to Environment / Components tab
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Pasang Komponen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentAmber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebServerCard(BuildContext context, ServerController controller) {
    final isInstalled = controller.components.php.isInstalled;
    final isRunning = controller.isWebRunning;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.dns_rounded, color: AppTheme.accentCyan, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Web Server', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis),
                            Text('Port 80 (HTTP) • Port 443 (HTTPS)', style: TextStyle(color: AppTheme.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch(
                  value: isRunning,
                  onChanged: isInstalled
                      ? (val) => controller.toggleWebServer(val)
                      : null,
                  activeColor: AppTheme.accentGreen,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderDark),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isInstalled)
                  const Text('Komponen PHP belum terpasang', style: TextStyle(color: AppTheme.accentAmber, fontSize: 12))
                else
                  Expanded(
                    child: Text(
                      isRunning ? 'Berjalan (Port 80)' : 'Berhenti',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isRunning ? AppTheme.accentGreen : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    if (!isInstalled)
                      InkWell(
                        onTap: () => onNavigate(7),
                        child: const Text('Pasang PHP', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    else
                      InkWell(
                        onTap: () => onNavigate(2), // Go to Web Server Engine view
                        child: Row(
                          children: const [
                            Text('Pengaturan', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.accentCyan),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMariaDbCard(BuildContext context, ServerController controller) {
    final isInstalled = controller.components.mariaDb.isInstalled;
    final isRunning = controller.isMariaDbRunning;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.storage_rounded, color: AppTheme.accentGreen, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('MariaDB Server', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white), overflow: TextOverflow.ellipsis),
                            Text('Port 3306 • MySQL Compatible', style: TextStyle(color: AppTheme.textMuted, fontSize: 12), overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Switch(
                  value: isRunning,
                  onChanged: isInstalled
                      ? (val) => controller.toggleMariaDb(val)
                      : null,
                  activeColor: AppTheme.accentGreen,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderDark),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!isInstalled)
                  const Text('MariaDB belum terpasang', style: TextStyle(color: AppTheme.accentAmber, fontSize: 12))
                else
                  Expanded(
                    child: Text(
                      isRunning ? 'Berjalan (Port 3306)' : 'Berhenti',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isRunning ? AppTheme.accentGreen : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    if (!isInstalled)
                      InkWell(
                        onTap: () => onNavigate(7),
                        child: const Text('Pasang MariaDB', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    else ...[
                      InkWell(
                        onTap: () => onNavigate(5), // Go to Turbo Importer
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
                          ),
                          child: const Text(
                            'SQL Importer',
                            style: TextStyle(color: AppTheme.accentAmber, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => onNavigate(4), // Go to MariaDB view
                        child: Row(
                          children: const [
                            Text('Pengaturan', style: TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios_rounded, size: 11, color: AppTheme.accentCyan),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhpInfoCard(BuildContext context, ServerController controller) {
    final php = controller.components.php;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentPurple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.code_rounded, color: AppTheme.accentPurple, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('PHP Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  Text(
                    php.isInstalled ? php.version : 'Belum Terpasang',
                    style: TextStyle(
                      color: php.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => onNavigate(3), // Go to PHP view
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: AppTheme.borderDark),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              child: const Text('Detail', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhpMyAdminCard(BuildContext context, ServerController controller) {
    final pma = controller.components.phpMyAdmin;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.table_chart_rounded, color: AppTheme.accentAmber, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('phpMyAdmin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                  Text(
                    pma.isInstalled ? 'Terpasang' : 'Belum Terpasang',
                    style: TextStyle(
                      color: pma.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (pma.isInstalled) ...[
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.textMuted),
                    tooltip: 'Info phpMyAdmin',
                    onPressed: () => onNavigate(6), // Go to PhpMyAdmin view
                  ),
                  const SizedBox(width: 4),
                ],
                ElevatedButton(
                  onPressed: pma.isInstalled
                      ? () => controller.openPhpMyAdmin()
                      : () => onNavigate(7),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pma.isInstalled ? AppTheme.accentBlue : AppTheme.cardHover,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: Text(pma.isInstalled ? 'Buka' : 'Pasang', style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSitesList(BuildContext context, ServerController controller) {
    if (controller.sites.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                const Icon(Icons.language_rounded, size: 40, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                const Text('Belum ada virtual host yang terdaftar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Tambahkan virtual host untuk mengarahkan domain lokal ke direktori proyek.', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(context: context, builder: (_) => const AddHostDialog());
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Tambah Host'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.sites.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderDark),
        itemBuilder: (context, index) {
          final site = controller.sites[index];

          return ListTile(
            leading: const Icon(Icons.public, color: AppTheme.accentCyan, size: 20),
            title: Text(
              site.domain,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
            ),
            subtitle: Text(
              site.type == 'proxy' ? 'Proxy -> Port ${site.proxyPort}' : site.rootPath,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.accentGreen),
                  tooltip: 'Buka HTTPS (https://${site.domain})',
                  onPressed: () => controller.openUrl('https://${site.domain}'),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.accentCyan),
                  tooltip: 'Buka HTTP (http://${site.domain})',
                  onPressed: () => controller.openUrl('http://${site.domain}'),
                ),
                if (site.type != 'proxy')
                  IconButton(
                    icon: const Icon(Icons.folder_open_rounded, size: 16, color: AppTheme.textSecondary),
                    tooltip: 'Buka Folder',
                    onPressed: () => controller.openFolder(site.rootPath),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.accentBlue),
                  tooltip: 'Edit Website',
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
