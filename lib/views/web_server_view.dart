import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/config_service.dart';
import '../services/hosts_manager.dart';
import '../services/server_controller.dart';
import '../services/ssl_service.dart';
import '../services/web_server_engine_manager.dart';
import '../theme/app_theme.dart';

class WebServerView extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const WebServerView({super.key, this.onNavigate});

  @override
  State<WebServerView> createState() => _WebServerViewState();
}

class _WebServerViewState extends State<WebServerView> {
  bool _isSyncingHosts = false;

  Future<void> _syncHosts() async {
    setState(() => _isSyncingHosts = true);
    await ServerController.instance.syncHosts();
    if (mounted) {
      setState(() => _isSyncingHosts = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi file hosts Windows & vhosts server selesai!'),
          backgroundColor: AppTheme.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openFile(String filePath) {
    if (File(filePath).existsSync()) {
      Process.run('notepad.exe', [filePath]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berkas ${File(filePath).path} belum dibuat atau belum ada.'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ServerController.instance,
        WebServerEngineManager.instance,
      ]),
      builder: (context, _) {
        final controller = ServerController.instance;
        final engineMgr = WebServerEngineManager.instance;
        final isRunning = controller.isWebRunning;
        final activeEngine = engineMgr.activeEngine;
        final sites = controller.sites;
        final activeSites = sites.where((s) => s.isEnabled).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Multi-Engine Selector Bar (FlyEnv / Laragon Standard)
              Card(
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
                              Icon(Icons.tune_rounded, size: 20, color: AppTheme.accentCyan),
                              SizedBox(width: 8),
                              Text(
                                'Pilih Web Server Engine Aktif (Port 80)',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                            ),
                            child: Text(
                              'ENGINE: ${activeEngine.toUpperCase()}',
                              style: const TextStyle(color: AppTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3 Engine Cards
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 750;
                          final cards = [
                            _buildEngineCard(
                              id: 'builtin',
                              title: 'Devlika Built-in',
                              subtitle: 'Native Async HTTP (Bawaan • Cepat & Ringan)',
                              badge: 'Bawaan (Siap)',
                              badgeColor: AppTheme.accentGreen,
                              icon: Icons.bolt_rounded,
                              iconColor: AppTheme.accentCyan,
                              isSelected: activeEngine == 'builtin',
                              isInstalled: true,
                              onSelect: () => controller.switchWebEngine('builtin'),
                            ),
                            _buildEngineCard(
                              id: 'nginx',
                              title: 'Nginx 1.26 Portable',
                              subtitle: 'High-Concurrency Event-Driven + FastCGI',
                              badge: controller.components.nginx.isInstalled ? 'Terpasang' : 'Perlu Unduh',
                              badgeColor: controller.components.nginx.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                              icon: Icons.dns_rounded,
                              iconColor: AppTheme.accentGreen,
                              isSelected: activeEngine == 'nginx',
                              isInstalled: controller.components.nginx.isInstalled,
                              onSelect: () => controller.switchWebEngine('nginx'),
                              onInstall: () => controller.installSingleComponent('nginx'),
                            ),
                            _buildEngineCard(
                              id: 'apache',
                              title: 'Apache HTTPD 2.4',
                              subtitle: 'Standar Industri dengan Native .htaccess',
                              badge: controller.components.apache.isInstalled ? 'Terpasang' : 'Perlu Unduh',
                              badgeColor: controller.components.apache.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                              icon: Icons.public_rounded,
                              iconColor: AppTheme.accentAmber,
                              isSelected: activeEngine == 'apache',
                              isInstalled: controller.components.apache.isInstalled,
                              onSelect: () => controller.switchWebEngine('apache'),
                              onInstall: () => controller.installSingleComponent('apache'),
                            ),
                          ];

                          return isWide
                              ? Row(
                                  children: [
                                    Expanded(child: cards[0]),
                                    const SizedBox(width: 12),
                                    Expanded(child: cards[1]),
                                    const SizedBox(width: 12),
                                    Expanded(child: cards[2]),
                                  ],
                                )
                              : Column(
                                  children: [
                                    cards[0],
                                    const SizedBox(height: 10),
                                    cards[1],
                                    const SizedBox(height: 10),
                                    cards[2],
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 2. Active Daemon Service Status Card
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
                          color: isRunning
                              ? AppTheme.accentCyan.withOpacity(0.15)
                              : AppTheme.cardHover,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRunning
                                ? AppTheme.accentCyan.withOpacity(0.4)
                                : AppTheme.borderDark,
                          ),
                        ),
                        child: Icon(
                          activeEngine == 'nginx'
                              ? Icons.dns_rounded
                              : (activeEngine == 'apache' ? Icons.public_rounded : Icons.bolt_rounded),
                          color: isRunning ? AppTheme.accentCyan : AppTheme.textSecondary,
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
                                Text(
                                  engineMgr.activeEngineDisplayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isRunning
                                        ? AppTheme.accentGreen.withOpacity(0.15)
                                        : Colors.grey.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isRunning
                                          ? AppTheme.accentGreen.withOpacity(0.4)
                                          : Colors.grey.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    isRunning ? 'BERJALAN' : 'BERHENTI',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              isRunning
                                  ? '🟢 Mendengarkan permintaan pada Port 80 & 443 (SSL/HTTPS) • Menangani ${activeSites.length} domain aktif'
                                  : '⚪ Server nonaktif. Klik tombol Start Server untuk mengaktifkan.',
                              style: TextStyle(
                                color: isRunning ? AppTheme.accentGreen : AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            if (isRunning) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentGreen)),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '🔒 SSL / HTTPS Aktif pada Port 443 (Wildcard SAN Dev CA)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.accentGreen,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (isRunning && (activeEngine == 'nginx' || activeEngine == 'apache')) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentPurple)),
                                  const SizedBox(width: 6),
                                  Text(
                                    engineMgr.isFastCgiRunning
                                        ? '🟣 PHP FastCGI Daemon aktif pada 127.0.0.1:9000'
                                        : '⚠️ PHP FastCGI Worker belum merespons port 9000',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: engineMgr.isFastCgiRunning ? AppTheme.accentPurple : AppTheme.accentAmber,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          if (isRunning) ...[
                            OutlinedButton.icon(
                              onPressed: () async {
                                final ok = await SslService.instance.installCertificateToWindowsStore();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Sertifikat SSL berhasil dipasang ke Windows Trusted Store!'
                                          : 'Pemasangan sertifikat dibatalkan atau selesai.'),
                                      backgroundColor: ok ? AppTheme.accentGreen : AppTheme.accentAmber,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.verified_user_rounded, size: 16),
                              label: const Text('Trust SSL'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentGreen,
                                side: BorderSide(color: AppTheme.accentGreen.withOpacity(0.4)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () => _openUrl('http://127.0.0.1'),
                              icon: const Icon(Icons.open_in_browser, size: 16),
                              label: const Text('Buka 127.0.0.1'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.accentCyan,
                                side: BorderSide(color: AppTheme.accentCyan.withOpacity(0.5)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          ElevatedButton.icon(
                            onPressed: () => controller.toggleWebServer(!isRunning),
                            icon: Icon(
                              isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                              size: 18,
                            ),
                            label: Text(
                              isRunning ? 'Stop Server' : 'Start Server',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isRunning ? AppTheme.accentRed : AppTheme.accentCyan,
                              foregroundColor: isRunning ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 3. Engine Tools & Configurations Card
              Card(
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
                              Icon(Icons.settings_suggest_rounded, size: 18, color: AppTheme.accentAmber),
                              SizedBox(width: 8),
                              Text(
                                'Konfigurasi & Pengaturan Berkas Server',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _isSyncingHosts ? null : _syncHosts,
                            icon: _isSyncingHosts
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(_isSyncingHosts ? 'Menyinkronkan...' : 'Sinkronkan Konfigurasi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.cardHover,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Engine Specific Action Buttons
                      if (activeEngine == 'nginx') ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openFile(ConfigService.instance.nginxConfFile),
                                icon: const Icon(Icons.edit_note_rounded, size: 16),
                                label: const Text('Edit nginx.conf'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => controller.openFolder(ConfigService.instance.nginxVhostsDir),
                                icon: const Icon(Icons.folder_open_rounded, size: 16),
                                label: const Text('Folder Vhosts Nginx'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                              ),
                            ),
                          ],
                        ),
                      ] else if (activeEngine == 'apache') ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openFile(ConfigService.instance.apacheConfFile),
                                icon: const Icon(Icons.edit_note_rounded, size: 16),
                                label: const Text('Edit httpd.conf'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openFile(ConfigService.instance.apacheVhostsFile),
                                icon: const Icon(Icons.edit_note_rounded, size: 16),
                                label: const Text('Edit httpd-vhosts.conf'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => controller.openFolder(ConfigService.instance.demoSiteDir),
                                icon: const Icon(Icons.folder_open_rounded, size: 16),
                                label: const Text('Folder Root Web (Demo Site)'),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),
                      _buildInfoRow('Port HTTP Utama', '80 (Default Web Standard)'),
                      const Divider(height: 16, color: AppTheme.borderDark),
                      _buildInfoRow('FastCGI PHP Daemon', activeEngine == 'builtin' ? 'Internal Pipe (Per-Request)' : '127.0.0.1:9000 (Persistent Pool)'),
                      const Divider(height: 16, color: AppTheme.borderDark),
                      _buildInfoRow('Lokasi Berkas Hosts Windows', r'C:\Windows\System32\drivers\etc\hosts'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 4. Active Virtual Hosts Routing Table
              Card(
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
                            children: [
                              const Icon(Icons.layers_rounded, size: 18, color: AppTheme.accentGreen),
                              const SizedBox(width: 8),
                              Text(
                                'Tabel Routing Virtual Host di $activeEngine',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${activeSites.length} Terhubung',
                                  style: const TextStyle(color: AppTheme.accentGreen, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          if (widget.onNavigate != null)
                            TextButton.icon(
                              onPressed: () => widget.onNavigate!(1), // Go to Hosts view
                              icon: const Icon(Icons.settings_outlined, size: 15),
                              label: const Text('Kelola Website di Halaman Hosts'),
                              style: TextButton.styleFrom(foregroundColor: AppTheme.accentCyan),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (activeSites.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.bgDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: const Center(
                            child: Text(
                              'Belum ada website lokal aktif. Tambahkan website pada menu Hosts.',
                              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2.5),
                                1: FlexColumnWidth(1.2),
                                2: FlexColumnWidth(4),
                                3: FixedColumnWidth(90),
                              },
                              children: [
                                TableRow(
                                  decoration: const BoxDecoration(color: AppTheme.bgDark),
                                  children: const [
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Text('Domain Virtual', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Text('Tipe / Runtime', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Text('Root Directory / Target', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      child: Text('Aksi', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                    ),
                                  ],
                                ),
                                ...activeSites.map((site) {
                                  return TableRow(
                                    decoration: const BoxDecoration(
                                      border: Border(top: BorderSide(color: AppTheme.borderDark)),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.language_rounded, size: 14, color: AppTheme.accentCyan),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                site.domain,
                                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Text(
                                          site.type == 'proxy' ? 'Proxy (Port ${site.proxyPort})' : 'PHP ${site.phpVersion}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: site.type == 'proxy' ? AppTheme.accentAmber : AppTheme.accentPurple,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                        child: Text(
                                          site.rootPath,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'Consolas'),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.accentGreen),
                                              tooltip: 'Buka https://${site.domain}',
                                              onPressed: () => _openUrl('https://${site.domain}'),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.open_in_browser_rounded, size: 16, color: AppTheme.accentCyan),
                                              tooltip: 'Buka http://${site.domain}',
                                              onPressed: () => _openUrl('http://${site.domain}'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
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

  Widget _buildEngineCard({
    required String id,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required bool isInstalled,
    required VoidCallback onSelect,
    VoidCallback? onInstall,
  }) {
    return InkWell(
      onTap: isInstalled ? onSelect : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentBlue.withOpacity(0.15) : AppTheme.bgDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentCyan : AppTheme.borderDark,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: badgeColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(color: badgeColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            if (!isInstalled && onInstall != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onInstall,
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('Unduh Sekarang', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentAmber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSelected ? '● Aktif Digunakan' : 'Klik untuk Beralih',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 180,
          child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Consolas'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
