import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/server_controller.dart';
import '../theme/app_theme.dart';

class PhpMyAdminView extends StatelessWidget {
  const PhpMyAdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServerController.instance,
      builder: (context, _) {
        final controller = ServerController.instance;
        final pma = controller.components.phpMyAdmin;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. phpMyAdmin Service Card
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: const Icon(Icons.table_view_rounded, color: AppTheme.textPrimary, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'phpMyAdmin Web GUI',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: pma.isInstalled ? AppTheme.accentGreen.withOpacity(0.1) : AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: pma.isInstalled ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.borderDark,
                                  ),
                                ),
                                child: Text(
                                  pma.isInstalled ? 'READY' : 'NOT INSTALLED',
                                  style: TextStyle(
                                    fontFamily: AppTheme.monoFont,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: pma.isInstalled ? AppTheme.accentGreen : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Antarmuka web resmi untuk administrasi, manipulasi tabel, dan query database MariaDB.',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (pma.isInstalled) ...[
                      ElevatedButton.icon(
                        onPressed: () => controller.openPhpMyAdmin(),
                        icon: const Icon(Icons.open_in_browser_rounded, size: 15, color: Colors.white),
                        label: const Text('Buka GUI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentIndigo,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () => controller.installSingleComponent('phpmyadmin'),
                        icon: const Icon(Icons.download_rounded, size: 15, color: Colors.white),
                        label: const Text('Pasang phpMyAdmin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentIndigo,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Direct Web Access URL
              if (pma.isInstalled) ...[
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Text(
                        'Direct URL:',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'http://127.0.0.1/__phpmyadmin/ (Auto-login user: root)',
                          style: TextStyle(
                            fontFamily: AppTheme.monoFont,
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 13, color: AppTheme.textMuted),
                        tooltip: 'Salin URL',
                        splashRadius: 14,
                        onPressed: () {
                          Clipboard.setData(const ClipboardData(text: 'http://127.0.0.1/__phpmyadmin/'));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('URL phpMyAdmin disalin ke clipboard.'),
                              backgroundColor: AppTheme.cardDark,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 3. Database Connection Parameters
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
                    const Text(
                      'Parameter Akses Otomatis phpMyAdmin',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    _buildRow('Database Server', 'MariaDB 3306 (MySQL Protocol)'),
                    const Divider(height: 14, color: AppTheme.borderDark),
                    _buildRow('Host Loopback', '127.0.0.1 / localhost'),
                    const Divider(height: 14, color: AppTheme.borderDark),
                    _buildRow('Default Port', '3306'),
                    const Divider(height: 14, color: AppTheme.borderDark),
                    _buildRow('Database User', 'root'),
                    const Divider(height: 14, color: AppTheme.borderDark),
                    _buildRow('Database Password', '(None / Kosong)'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 150, child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12))),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: AppTheme.monoFont,
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
