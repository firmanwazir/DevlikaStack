import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/server_controller.dart';

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
      animation: ServerController.instance,
      builder: (context, _) {
        final controller = ServerController.instance;
        final isWebOn = controller.isWebRunning;
        final isDbOn = controller.isMariaDbRunning;
        final isAllOn = isWebOn && isDbOn;
        final activeSitesCount = controller.sites.where((s) => s.isEnabled).length;

        return Container(
          width: 250,
          decoration: const BoxDecoration(
            color: AppTheme.sidebarDark,
            border: Border(
              right: BorderSide(color: AppTheme.borderDark, width: 1),
            ),
          ),
          child: Column(
            children: [
              // 1. Brand Logo Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.accentCyan, AppTheme.accentBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCyan.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.layers_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentCyan.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
                                ),
                                child: const Text(
                                  'v2.1',
                                  style: TextStyle(color: AppTheme.accentCyan, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Portable Server Stack',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.textSecondary.withOpacity(0.8),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppTheme.borderDark),

              // 2. FlyEnv Categorized Navigation List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  children: [
                    // CATEGORY: OVERVIEW
                    _buildSectionHeader('OVERVIEW'),
                    _buildNavItem(
                      index: 0,
                      title: 'Dashboard',
                      icon: Icons.dashboard_rounded,
                      badge: isAllOn
                          ? 'Running'
                          : (isWebOn || isDbOn ? 'Partial' : null),
                      badgeColor: isAllOn
                          ? AppTheme.accentGreen
                          : (isWebOn || isDbOn ? AppTheme.accentAmber : null),
                    ),

                    const SizedBox(height: 6),

                    // CATEGORY: PROJECTS
                    _buildSectionHeader('PROJECTS'),
                    _buildNavItem(
                      index: 1,
                      title: 'Virtual Hosts',
                      icon: Icons.language_rounded,
                      badge: '$activeSitesCount Hosts',
                      badgeColor: AppTheme.accentCyan,
                    ),

                    const SizedBox(height: 6),

                    // CATEGORY: SERVERS
                    _buildSectionHeader('SERVERS & RUNTIME'),
                    _buildNavItem(
                      index: 2,
                      title: 'Web Server',
                      icon: Icons.dns_rounded,
                      badge: isWebOn ? 'Port 80' : 'Stopped',
                      badgeColor: isWebOn ? AppTheme.accentGreen : AppTheme.textMuted,
                      isServiceRunning: isWebOn,
                    ),
                    _buildNavItem(
                      index: 3,
                      title: 'PHP Environment',
                      icon: Icons.code_rounded,
                      badge: 'PHP 8.2',
                      badgeColor: AppTheme.accentPurple,
                    ),

                    const SizedBox(height: 6),

                    // CATEGORY: DATABASE
                    _buildSectionHeader('DATABASE'),
                    _buildNavItem(
                      index: 4,
                      title: 'MariaDB Server',
                      icon: Icons.storage_rounded,
                      badge: isDbOn ? 'Port 3306' : 'Stopped',
                      badgeColor: isDbOn ? AppTheme.accentGreen : AppTheme.textMuted,
                      isServiceRunning: isDbOn,
                    ),
                    _buildNavItem(
                      index: 5,
                      title: 'SQL Importer',
                      icon: Icons.bolt_rounded,
                      badge: 'Dump',
                      badgeColor: AppTheme.accentAmber,
                    ),
                    _buildNavItem(
                      index: 6,
                      title: 'phpMyAdmin',
                      icon: Icons.table_chart_rounded,
                      badge: 'Web GUI',
                      badgeColor: AppTheme.accentBlue,
                    ),

                    const SizedBox(height: 6),

                    // CATEGORY: SYSTEM
                    _buildSectionHeader('SYSTEM & TOOLS'),
                    _buildNavItem(
                      index: 7,
                      title: 'Komponen Server',
                      icon: Icons.inventory_2_rounded,
                      badge: controller.components.isAllInstalled ? 'Ready' : 'Download',
                      badgeColor: controller.components.isAllInstalled ? AppTheme.accentGreen : AppTheme.accentAmber,
                    ),
                    _buildNavItem(
                      index: 8,
                      title: 'Log Aktivitas',
                      icon: Icons.terminal_rounded,
                      badge: 'Live',
                      badgeColor: AppTheme.accentCyan,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppTheme.borderDark),

              // 3. Bottom Master Control Toolbar (FlyEnv Style)
              Container(
                padding: const EdgeInsets.all(12),
                color: AppTheme.bgDark.withOpacity(0.6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isAllOn
                                ? AppTheme.accentGreen
                                : (isWebOn || isDbOn ? AppTheme.accentAmber : AppTheme.accentRed),
                            boxShadow: [
                              if (isAllOn || isWebOn || isDbOn)
                                BoxShadow(
                                  color: (isAllOn ? AppTheme.accentGreen : AppTheme.accentAmber).withOpacity(0.6),
                                  blurRadius: 6,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isAllOn
                                ? 'Semua Layanan Berjalan'
                                : (isWebOn || isDbOn ? 'Sebagian Berjalan' : 'Semua Layanan Berhenti'),
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
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => controller.startAll(),
                            icon: const Icon(Icons.play_arrow_rounded, size: 14),
                            label: const Text('Start All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentGreen.withOpacity(0.18),
                              foregroundColor: AppTheme.accentGreen,
                              side: BorderSide(color: AppTheme.accentGreen.withOpacity(0.35)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => controller.stopAll(),
                            icon: const Icon(Icons.stop_rounded, size: 14),
                            label: const Text('Stop All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentRed.withOpacity(0.18),
                              foregroundColor: AppTheme.accentRed,
                              side: BorderSide(color: AppTheme.accentRed.withOpacity(0.35)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
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
      padding: const EdgeInsets.only(left: 10, right: 10, top: 10, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
    String? badge,
    Color? badgeColor,
    bool isServiceRunning = false,
  }) {
    final isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onItemSelected(index),
          hoverColor: AppTheme.cardHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.accentBlue.withOpacity(0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: AppTheme.accentCyan.withOpacity(0.4), width: 1)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 17,
                  color: isSelected
                      ? AppTheme.accentCyan
                      : (isServiceRunning ? AppTheme.accentGreen : AppTheme.textSecondary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: (badgeColor ?? AppTheme.textSecondary).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: (badgeColor ?? AppTheme.textSecondary).withOpacity(0.3), width: 0.8),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: badgeColor ?? AppTheme.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isSelected && badge == null)
                  Container(
                    width: 4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan,
                      borderRadius: BorderRadius.circular(2),
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
