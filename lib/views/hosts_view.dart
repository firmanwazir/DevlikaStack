import 'package:flutter/material.dart';
import '../models/site_model.dart';
import '../services/server_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/add_host_dialog.dart';

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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Quick Stats Summary
              Row(
                children: [
                  _buildStatBadge(
                    icon: Icons.language_rounded,
                    label: 'Total Website',
                    value: '$totalCount',
                    color: AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBadge(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Website Aktif',
                    value: '$activeCount',
                    color: AppTheme.accentGreen,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBadge(
                    icon: Icons.code_rounded,
                    label: 'PHP Host',
                    value: '$phpCount',
                    color: AppTheme.accentPurple,
                  ),
                  const SizedBox(width: 12),
                  _buildStatBadge(
                    icon: Icons.alt_route_rounded,
                    label: 'Reverse Proxy',
                    value: '$proxyCount',
                    color: AppTheme.accentAmber,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Search & Add Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari website berdasarkan domain, path, atau versi PHP...',
                        hintStyle: const TextStyle(color: AppTheme.textMuted),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16, color: AppTheme.textMuted),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppTheme.cardDark,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.borderDark),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppTheme.borderDark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AddHostDialog(),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Tambah Website (Host)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Sites Table / Empty State
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

  Widget _buildStatBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {required bool isSearch}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardDark,
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Icon(
              isSearch ? Icons.search_off_rounded : Icons.language_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isSearch ? 'Tidak ada website yang cocok dengan pencarian' : 'Belum Ada Website Lokal Terdaftar',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Coba gunakan kata kunci domain atau nama folder lainnya.'
                : 'Daftarkan domain lokalmu agar bisa diakses langsung via browser (contoh: myproject.local).',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(context: context, builder: (_) => const AddHostDialog());
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tambah Website Sekarang'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSitesTable(
    BuildContext context,
    ServerController controller,
    List<SiteModel> sites,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF131823),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: AppTheme.borderDark)),
            ),
            child: Row(
              children: const [
                SizedBox(width: 60, child: Text('STATUS', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('DOMAIN LOKAL', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('ENGINE / VERSI', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text('FOLDER PROYEK / TARGET', style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 170, child: Text('AKSI', textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      // Status Switch (Toggle Aktif / Nonaktif)
                      SizedBox(
                        width: 60,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Switch(
                            value: site.isEnabled,
                            activeColor: AppTheme.accentGreen,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) {
                              controller.toggleSite(site.id, val);
                            },
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
                                const Icon(Icons.language_rounded, size: 15, color: AppTheme.accentCyan),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    site.domain,
                                    style: const TextStyle(
                                      fontFamily: 'Consolas',
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.accentCyan,
                                      fontSize: 13,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: site.type == 'proxy'
                                  ? AppTheme.accentAmber.withOpacity(0.12)
                                  : AppTheme.accentPurple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: site.type == 'proxy'
                                    ? AppTheme.accentAmber.withOpacity(0.3)
                                    : AppTheme.accentPurple.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  site.type == 'proxy' ? Icons.alt_route_rounded : Icons.code_rounded,
                                  size: 12,
                                  color: site.type == 'proxy' ? AppTheme.accentAmber : AppTheme.accentPurple,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  site.type == 'proxy'
                                      ? 'PROXY :${site.proxyPort}'
                                      : (site.phpVersion == 'default' ? 'PHP Default' : 'PHP ${site.phpVersion}'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: site.type == 'proxy' ? AppTheme.accentAmber : AppTheme.accentPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Folder / Port
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
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontFamily: 'Consolas',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),

                      // Actions: Open Browser, Open Folder, Edit, Delete
                      SizedBox(
                        width: 205,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Buka HTTPS
                            IconButton(
                              icon: const Icon(Icons.lock_outline_rounded, size: 16),
                              tooltip: 'Buka HTTPS (https://${site.domain})',
                              color: AppTheme.accentGreen,
                              onPressed: () => controller.openUrl('https://${site.domain}'),
                            ),

                            // Buka HTTP
                            IconButton(
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              tooltip: 'Buka HTTP (http://${site.domain})',
                              color: AppTheme.accentCyan,
                              onPressed: () => controller.openUrl('http://${site.domain}'),
                            ),

                            // Buka Folder Proyek
                            if (site.type != 'proxy')
                              IconButton(
                                icon: const Icon(Icons.folder_open_rounded, size: 16),
                                tooltip: 'Buka Folder Proyek',
                                color: AppTheme.textSecondary,
                                onPressed: () => controller.openFolder(site.rootPath),
                              ),

                            // EDIT WEBSITE BUTTON
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              tooltip: 'Edit Konfigurasi Website',
                              color: AppTheme.accentBlue,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AddHostDialog(siteToEdit: site),
                                );
                              },
                            ),

                            // Hapus Website
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              tooltip: 'Hapus Website',
                              color: AppTheme.accentRed,
                              onPressed: () {
                                _confirmDelete(context, controller, site);
                              },
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
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 22),
            SizedBox(width: 10),
            Text('Hapus Website', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah kamu yakin ingin menghapus website ${site.domain}?',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text(
              'Domain ini tidak akan diarahkan lagi oleh server lokal (file proyekmu tetap aman).',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.deleteSite(site.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Website ${site.domain} telah dihapus.'),
                  backgroundColor: AppTheme.accentRed,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }
}
