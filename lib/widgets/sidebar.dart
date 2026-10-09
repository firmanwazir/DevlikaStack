import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/server_controller.dart';
import '../services/tunnel_service.dart';

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const Sidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([ServerController.instance, TunnelService.instance]),
      builder: (context, _) {
        final controller = ServerController.instance;
        final isWebOn = controller.isWebRunning;
        final isDbOn = controller.isMariaDbRunning;
        final isAllOn = isWebOn && isDbOn;
        final isTunnelOn = TunnelService.instance.isRunning;
        final activeSitesCount = controller.sites.length;

        return Container(
          width: 240,
          decoration: const BoxDecoration(
            color: AppTheme.sidebarDark,
            border: Border(
              right: BorderSide(color: AppTheme.borderDark, width: 1),
            ),
          ),
          child: Column(
            children: [
              // 1. Sleek Brand Header (Developer Tool Identity)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2330),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2E364A), width: 1),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.dns_rounded,
                          color: AppTheme.accentIndigo,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Flexible(
                                child: Text(
                                  'DevlikaStack',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.borderDark),
                                ),
                                child: const Text(
                                  'v2.1',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Local Server Suite',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppTheme.borderDark),

              // 2. Minimalist, Quiet Navigation (No Badge Fatigue)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  children: [
                    // CATEGORY: OVERVIEW
                    _buildSectionHeader('WORKSPACE'),
                    _buildNavItem(
                      index: 0,
                      title: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      statusColor: isAllOn
                          ? AppTheme.accentGreen
                          : (isWebOn || isDbOn ? AppTheme.accentAmber : null),
                    ),
                    _buildNavItem(
                      index: 1,
                      title: 'Virtual Hosts',
                      icon: Icons.public_outlined,
                      activeIcon: Icons.public,
                      countBadge: activeSitesCount > 0 ? '$activeSitesCount' : null,
                    ),

                    const SizedBox(height: 10),

                    // CATEGORY: RUNTIME
                    _buildSectionHeader('SERVERS & RUNTIME'),
                    _buildNavItem(
                      index: 2,
                      title: 'Web Server',
                      icon: Icons.hub_outlined,
                      activeIcon: Icons.hub_rounded,
                      statusColor: isWebOn ? AppTheme.accentGreen : null,
                    ),
                    _buildNavItem(
                      index: 3,
                      title: 'PHP Environment',
                      icon: Icons.code_rounded,
                      activeIcon: Icons.code_rounded,
                    ),

                    const SizedBox(height: 10),

                    // CATEGORY: DATABASE
                    _buildSectionHeader('DATABASE'),
                    _buildNavItem(
                      index: 4,
                      title: 'MariaDB Server',
                      icon: Icons.storage_outlined,
                      activeIcon: Icons.storage_rounded,
                      statusColor: isDbOn ? AppTheme.accentGreen : null,
                    ),
                    _buildNavItem(
                      index: 5,
                      title: 'SQL Importer',
                      icon: Icons.bolt_outlined,
                      activeIcon: Icons.bolt_rounded,
                    ),
                    _buildNavItem(
                      index: 6,
                      title: 'phpMyAdmin',
                      icon: Icons.table_view_outlined,
                      activeIcon: Icons.table_view_rounded,
                    ),

                    const SizedBox(height: 10),

                    // CATEGORY: SYSTEM
                    _buildSectionHeader('SYSTEM & TOOLS'),
                    _buildNavItem(
                      index: 9,
                      title: 'Cloudflare Tunnel',
                      icon: Icons.cloud_outlined,
                      activeIcon: Icons.cloud_rounded,
                      statusColor: isTunnelOn ? AppTheme.accentGreen : null,
                    ),
                    _buildNavItem(
                      index: 7,
                      title: 'Pusat Komponen',
                      icon: Icons.widgets_outlined,
                      activeIcon: Icons.widgets_rounded,
                    ),
                    _buildNavItem(
                      index: 8,
                      title: 'Log Aktivitas',
                      icon: Icons.terminal_outlined,
                      activeIcon: Icons.terminal_rounded,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppTheme.borderDark),

              // 3. Compact Native Control Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                color: AppTheme.surfaceSubtle,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAllOn
                                ? AppTheme.accentGreen
                                : (isWebOn || isDbOn ? AppTheme.accentAmber : AppTheme.textMuted),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isAllOn
                                ? 'Semua Layanan Berjalan'
                                : (isWebOn || isDbOn ? 'Sebagian Layanan Aktif' : 'Semua Layanan Berhenti'),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.startAll(),
                            icon: const Icon(Icons.play_arrow_rounded, size: 14, color: AppTheme.accentGreen),
                            label: const Text('Start', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              backgroundColor: AppTheme.cardDark,
                              side: const BorderSide(color: AppTheme.borderDark),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => controller.stopAll(),
                            icon: const Icon(Icons.stop_rounded, size: 14, color: AppTheme.accentRed),
                            label: const Text('Stop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              backgroundColor: AppTheme.cardDark,
                              side: const BorderSide(color: AppTheme.borderDark),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
    required IconData activeIcon,
    Color? statusColor,
    String? countBadge,
  }) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onItemSelected(index),
          hoverColor: AppTheme.cardHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E2330) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: const Color(0xFF2E374A), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 16,
                  color: isSelected
                      ? AppTheme.accentIndigo
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                // Clean Status Dot (For running services)
                if (statusColor != null)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                // Quiet Count Badge (For virtual hosts count)
                if (countBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: Text(
                      countBadge,
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
          ),
        ),
      ),
    );
  }
}
