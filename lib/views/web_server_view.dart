import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/config_service.dart';
import '../services/hosts_manager.dart';
import '../services/server_controller.dart';
import '../services/ssl_service.dart';
import '../services/web_server_engine_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/port_settings_dialog.dart';

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
          backgroundColor: AppTheme.cardDark,
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
          backgroundColor: AppTheme.cardDark,
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Multi-Engine Selector (Developer Segmented Cards)
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Web Server Engine',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (ctx) => const PortSettingsDialog(),
                              ),
                              icon: const Icon(Icons.lan_outlined, size: 13, color: AppTheme.accentIndigo),
                              label: Text(
                                'Port: ${controller.httpPort}',
                                style: const TextStyle(fontFamily: AppTheme.monoFont, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textPrimary,
                                side: const BorderSide(color: AppTheme.borderDark),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.borderDark),
                              ),
                              child: Text(
                                'ACTIVE: ${activeEngine.toUpperCase()}',
                                style: const TextStyle(
                                  fontFamily: AppTheme.monoFont,
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Engine Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 750;
                        final cards = [
                          _buildEngineCard(
                            id: 'builtin',
                            title: 'Devlika Built-in',
                            subtitle: 'Native Async HTTP runtime (Zero dependency)',
                            badge: 'Default',
                            badgeColor: AppTheme.accentGreen,
                            icon: Icons.bolt_rounded,
                            isSelected: activeEngine == 'builtin',
                            isInstalled: true,
                            onSelect: () => controller.switchWebEngine('builtin'),
                          ),
                          _buildEngineCard(
                            id: 'nginx',
                            title: 'Nginx 1.26',
                            subtitle: 'High performance event-driven HTTP & reverse proxy',
                            badge: controller.components.nginx.isInstalled ? 'Ready' : 'Belum Ada',
                            badgeColor: controller.components.nginx.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                            icon: Icons.hub_rounded,
                            isSelected: activeEngine == 'nginx',
                            isInstalled: controller.components.nginx.isInstalled,
                            onSelect: () => controller.switchWebEngine('nginx'),
                            onInstall: () => controller.installSingleComponent('nginx'),
                          ),
                          _buildEngineCard(
                            id: 'apache',
                            title: 'Apache HTTPD 2.4',
                            subtitle: 'Traditional Apache server dengan dukungan .htaccess mod_rewrite',
                            badge: controller.components.apache.isInstalled ? 'Ready' : 'Belum Ada',
                            badgeColor: controller.components.apache.isInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                            icon: Icons.public_rounded,
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
                                  const SizedBox(width: 10),
                                  Expanded(child: cards[1]),
                                  const SizedBox(width: 10),
                                  Expanded(child: cards[2]),
                                ],
                              )
                            : Column(
                                children: [
                                  cards[0],
                                  const SizedBox(height: 8),
                                  cards[1],
                                  const SizedBox(height: 8),
                                  cards[2],
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Active Daemon Status Module
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
                      child: Icon(
                        activeEngine == 'nginx'
                            ? Icons.hub_rounded
                            : (activeEngine == 'apache' ? Icons.public_rounded : Icons.bolt_rounded),
                        color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                engineMgr.activeEngineDisplayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isRunning ? AppTheme.accentGreen.withOpacity(0.1) : AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isRunning ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.borderDark,
                                  ),
                                ),
                                child: Text(
                                  isRunning ? 'ONLINE' : 'STOPPED',
                                  style: TextStyle(
                                    fontFamily: AppTheme.monoFont,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isRunning
                                ? 'Port ${controller.httpPort} (HTTP) • Port ${controller.httpsPort} (HTTPS) • ${activeSites.length} domain terhubung'
                                : 'Layanan web server sedang berhenti.',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          if (isRunning && (activeEngine == 'nginx' || activeEngine == 'apache')) ...[
                            const SizedBox(height: 3),
                            Text(
                              engineMgr.isFastCgiRunning
                                  ? 'FastCGI pool aktif pada 127.0.0.1:9000'
                                  : 'FastCGI worker belum aktif pada port 9000',
                              style: TextStyle(
                                fontFamily: AppTheme.monoFont,
                                fontSize: 11,
                                color: engineMgr.isFastCgiRunning ? AppTheme.textSecondary : AppTheme.accentAmber,
                              ),
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
                                    backgroundColor: AppTheme.cardDark,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.verified_user_rounded, size: 14),
                            label: const Text('Trust SSL', style: TextStyle(fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              backgroundColor: AppTheme.surfaceSubtle,
                              side: const BorderSide(color: AppTheme.borderDark),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openUrl('http://127.0.0.1'),
                            icon: const Icon(Icons.open_in_browser_rounded, size: 14),
                            label: const Text('Buka 127.0.0.1', style: TextStyle(fontSize: 11.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              backgroundColor: AppTheme.surfaceSubtle,
                              side: const BorderSide(color: AppTheme.borderDark),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          onPressed: () => controller.toggleWebServer(!isRunning),
                          icon: Icon(
                            isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          label: Text(
                            isRunning ? 'Stop Server' : 'Start Server',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isRunning ? const Color(0xFFBE123C) : const Color(0xFF047857),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Configurations Module
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Konfigurasi & Berkas Engine',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isSyncingHosts ? null : _syncHosts,
                          icon: _isSyncingHosts
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync_rounded, size: 14),
                          label: Text(_isSyncingHosts ? 'Menyinkronkan...' : 'Sinkronkan Hosts', style: const TextStyle(fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            backgroundColor: AppTheme.surfaceSubtle,
                            side: const BorderSide(color: AppTheme.borderDark),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Engine-specific Buttons
                    if (activeEngine == 'nginx') ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openFile(ConfigService.instance.nginxConfFile),
                              icon: const Icon(Icons.edit_note_rounded, size: 15),
                              label: const Text('Edit nginx.conf', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, padding: const EdgeInsets.symmetric(vertical: 10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => controller.openFolder(ConfigService.instance.nginxVhostsDir),
                              icon: const Icon(Icons.folder_open_outlined, size: 15),
                              label: const Text('Folder Vhosts Nginx', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, padding: const EdgeInsets.symmetric(vertical: 10)),
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
                              icon: const Icon(Icons.edit_note_rounded, size: 15),
                              label: const Text('Edit httpd.conf', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, padding: const EdgeInsets.symmetric(vertical: 10)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _openFile(ConfigService.instance.apacheVhostsFile),
                              icon: const Icon(Icons.edit_note_rounded, size: 15),
                              label: const Text('Edit httpd-vhosts.conf', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, padding: const EdgeInsets.symmetric(vertical: 10)),
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
                              icon: const Icon(Icons.folder_open_outlined, size: 15),
                              label: const Text('Folder Demo Site', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textPrimary, padding: const EdgeInsets.symmetric(vertical: 10)),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoRow('Port Jaringan', 'HTTP: ${controller.httpPort}  |  HTTPS: ${controller.httpsPort}'),
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
                    _buildInfoRow('FastCGI Daemon', activeEngine == 'builtin' ? 'Internal Pipe' : '127.0.0.1:9000 (Persistent Pool)'),
                    const Divider(height: 14, color: AppTheme.borderDark),
                    _buildInfoRow('File Hosts Windows', r'C:\Windows\System32\drivers\etc\hosts'),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 4. Routing Table Card
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Routing Virtual Host ($activeEngine)',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceSubtle,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.borderDark),
                              ),
                              child: Text(
                                '${activeSites.length} Terhubung',
                                style: const TextStyle(
                                  fontFamily: AppTheme.monoFont,
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (widget.onNavigate != null)
                          TextButton.icon(
                            onPressed: () => widget.onNavigate!(1),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 13),
                            label: const Text('Kelola di Menu Hosts'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (activeSites.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: const Center(
                          child: Text(
                            'Belum ada virtual host yang aktif. Tambahkan host pada menu Virtual Hosts.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(2.5),
                              1: FlexColumnWidth(1.2),
                              2: FlexColumnWidth(4),
                              3: FixedColumnWidth(80),
                            },
                            children: [
                              TableRow(
                                decoration: const BoxDecoration(color: AppTheme.surfaceSubtle),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('DOMAIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('RUNTIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('ROOT DIRECTORY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text('AKSI', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.5)),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      child: Text(
                                        site.domain,
                                        style: const TextStyle(
                                          fontFamily: AppTheme.monoFont,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      child: Text(
                                        site.type == 'proxy' ? 'Proxy :${site.proxyPort}' : 'PHP ${site.phpVersion}',
                                        style: const TextStyle(
                                          fontFamily: AppTheme.monoFont,
                                          fontSize: 11,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                      child: Text(
                                        site.rootPath,
                                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted, fontFamily: AppTheme.monoFont),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.lock_outline_rounded, size: 14, color: AppTheme.accentGreen),
                                            tooltip: 'Buka https://${site.domain}',
                                            splashRadius: 14,
                                            onPressed: () => _openUrl('https://${site.domain}'),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.open_in_browser_rounded, size: 14, color: AppTheme.textSecondary),
                                            tooltip: 'Buka http://${site.domain}',
                                            splashRadius: 14,
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
    required bool isSelected,
    required bool isInstalled,
    required VoidCallback onSelect,
    VoidCallback? onInstall,
  }) {
    return InkWell(
      onTap: isInstalled ? onSelect : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E2330) : AppTheme.surfaceSubtle,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E374A) : AppTheme.borderDark,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: isSelected ? AppTheme.accentIndigo : AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontFamily: AppTheme.monoFont,
                      color: badgeColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isInstalled && onInstall != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onInstall,
                  icon: const Icon(Icons.download_rounded, size: 12),
                  label: const Text('Unduh Engine', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentAmber,
                    side: BorderSide(color: AppTheme.accentAmber.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.monoFont,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
