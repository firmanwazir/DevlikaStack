import 'package:flutter/material.dart';
import '../models/site_model.dart';
import '../services/server_controller.dart';
import '../services/tunnel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_host_dialog.dart';
import '../widgets/tunnel_dialog.dart';

class HostsView extends StatefulWidget {
  const HostsView({super.key});

  @override
  State<HostsView> createState() => _HostsViewState();
}

class _HostsViewState extends State<HostsView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServerController.instance,
      builder: (context, _) {
        final controller = ServerController.instance;
        final allSites = controller.sites;
        final filteredSites = allSites.where((s) {
          final query = _searchQuery.toLowerCase();
          return s.domain.toLowerCase().contains(query) ||
              s.rootPath.toLowerCase().contains(query) ||
              s.phpVersion.toLowerCase().contains(query);
        }).toList();

        final totalCount = allSites.length;
        final activeCount = allSites.where((s) => s.isEnabled).length;
        final phpCount = allSites.where((s) => s.type != 'proxy').length;
        final proxyCount = allSites.where((s) => s.type == 'proxy').length;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. High-Density Technical Metric Strip (Developer Tool Style)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildMetricItem('TOTAL HOSTS', '$totalCount', null),
                    _buildVerticalDivider(),
                    _buildMetricItem('AKTIF', '$activeCount', AppTheme.accentGreen),
                    _buildVerticalDivider(),
                    _buildMetricItem('PHP RUNTIME', '$phpCount', null),
                    _buildVerticalDivider(),
                    _buildMetricItem('REVERSE PROXY', '$proxyCount', null),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Search & Add Toolbar
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Cari domain, folder root, atau runtime...',
                          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12.5),
                          prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 14, color: AppTheme.textMuted),
                                  splashRadius: 14,
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: AppTheme.cardDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const AddHostDialog(),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 15),
                      label: const Text('Tambah Virtual Host', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Data Table or Empty State
              Expanded(
                child: filteredSites.isEmpty
                    ? _buildEmptyState(context, isSearch: _searchQuery.isNotEmpty)
                    : _buildSitesTable(context, controller, filteredSites),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem(String label, String value, Color? statusDot) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (statusDot != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: statusDot),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: AppTheme.monoFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 24,
      color: AppTheme.borderDark,
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isSearch}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardDark,
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Icon(
              isSearch ? Icons.search_off_rounded : Icons.public_off_rounded,
              size: 32,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isSearch ? 'Tidak ada host yang cocok dengan pencarian' : 'Belum Ada Virtual Host',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            isSearch
                ? 'Coba gunakan kata kunci domain atau nama folder lainnya.'
                : 'Daftarkan domain lokal (contoh: project.local) untuk diarahkan ke folder proyek.',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          if (!isSearch) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(context: context, builder: (_) => const AddHostDialog());
              },
              icon: const Icon(Icons.add_rounded, size: 15),
              label: const Text('Tambah Virtual Host', style: TextStyle(fontSize: 12.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSitesTable(
    BuildContext context,
    ServerController controller,
    List<SiteModel> sites,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: AppTheme.borderDark)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 48, child: Text('STATUS', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                Expanded(flex: 3, child: Text('DOMAIN', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('RUNTIME', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                Expanded(flex: 5, child: Text('DOCUMENT ROOT / PROXY TARGET', style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                SizedBox(width: 220, child: Text('AKSI', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
              ],
            ),
          ),

          // Table Rows
          Expanded(
            child: ListView.separated(
              itemCount: sites.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderDark),
              itemBuilder: (context, index) {
                final site = sites[index];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Status Switch
                      SizedBox(
                        width: 48,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Transform.scale(
                            scale: 0.72,
                            child: Switch(
                              value: site.isEnabled,
                              activeColor: AppTheme.accentGreen,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) => controller.toggleSite(site.id, val),
                            ),
                          ),
                        ),
                      ),

                      // Domain Lokal
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: () => controller.openUrl('http://${site.domain}'),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.public, size: 14, color: AppTheme.textMuted),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    site.domain,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.monoFont,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                      fontSize: 12.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Engine / PHP Version Badge
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceSubtle,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.borderDark),
                            ),
                            child: Text(
                              site.type == 'proxy'
                                  ? 'PROXY :${site.proxyPort}'
                                  : (site.phpVersion == 'default' ? 'PHP Default' : 'PHP ${site.phpVersion}'),
                              style: const TextStyle(
                                fontFamily: AppTheme.monoFont,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Document Root / Proxy Port
                      Expanded(
                        flex: 5,
                        child: Tooltip(
                          message: site.type == 'proxy'
                              ? 'Reverse Proxy ke port 127.0.0.1:${site.proxyPort}'
                              : site.rootPath,
                          child: Text(
                            site.type == 'proxy'
                                ? 'Reverse Proxy -> 127.0.0.1:${site.proxyPort}'
                                : site.rootPath,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11.5,
                              fontFamily: AppTheme.monoFont,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      // Actions
                      SizedBox(
                        width: 220,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Cloudflare Quick Tunnel Button
                            AnimatedBuilder(
                              animation: TunnelService.instance,
                              builder: (context, _) {
                                final tunnel = TunnelService.instance;
                                final isActive = tunnel.isRunning && tunnel.activeDomain == site.domain;
                                final isStarting = tunnel.isStarting && tunnel.activeDomain == site.domain;

                                return IconButton(
                                  icon: Icon(
                                    isActive
                                        ? Icons.cloud_done_rounded
                                        : (isStarting ? Icons.cloud_sync_rounded : Icons.cloud_outlined),
                                    size: 15,
                                  ),
                                  splashRadius: 15,
                                  tooltip: isActive
                                      ? 'Tunnel Aktif (${tunnel.publicUrl}) - Klik info'
                                      : 'Bagikan ke Internet (Cloudflare Tunnel)',
                                  color: isActive
                                      ? AppTheme.accentGreen
                                      : (isStarting ? AppTheme.accentAmber : AppTheme.textSecondary),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => TunnelDialog(site: site),
                                    );
                                  },
                                );
                              },
                            ),

                            // HTTPS
                            IconButton(
                              icon: const Icon(Icons.lock_outline_rounded, size: 14),
                              tooltip: 'Buka HTTPS (https://${site.domain})',
                              splashRadius: 15,
                              color: AppTheme.accentGreen,
                              onPressed: () => controller.openUrl('https://${site.domain}'),
                            ),

                            // HTTP
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                              tooltip: 'Buka HTTP (http://${site.domain})',
                              splashRadius: 15,
                              color: AppTheme.textSecondary,
                              onPressed: () => controller.openUrl('http://${site.domain}'),
                            ),

                            // Open Folder
                            if (site.type != 'proxy')
                              IconButton(
                                icon: const Icon(Icons.folder_open_outlined, size: 14),
                                tooltip: 'Buka Folder Root',
                                splashRadius: 15,
                                color: AppTheme.textSecondary,
                                onPressed: () => controller.openFolder(site.rootPath),
                              ),

                            // Edit Host
                            IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 14),
                              tooltip: 'Edit Konfigurasi Host',
                              splashRadius: 15,
                              color: AppTheme.textSecondary,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AddHostDialog(siteToEdit: site),
                                );
                              },
                            ),

                            // Delete Host
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 14),
                              tooltip: 'Hapus Host',
                              splashRadius: 15,
                              color: AppTheme.accentRed,
                              onPressed: () => _confirmDelete(context, controller, site),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ServerController controller, SiteModel site) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 20),
            SizedBox(width: 8),
            Text('Hapus Virtual Host', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konfirmasi penghapusan konfigurasi virtual host ${site.domain}?',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            const Text(
              'Routing domain ini akan dinonaktifkan. File pada folder proyek Anda tidak akan dihapus.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteSite(site.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Virtual host ${site.domain} telah dihapus.'),
                  backgroundColor: AppTheme.cardDark,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Hapus Host', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
