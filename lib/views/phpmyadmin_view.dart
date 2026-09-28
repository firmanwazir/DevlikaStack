import 'package:flutter/material.dart';
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentAmber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.table_chart_rounded, color: AppTheme.accentAmber, size: 48),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'phpMyAdmin Database Manager',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Kelola tabel, struktur, relasi, eksekusi kueri SQL, dan ekspor/impor database secara visual.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        if (pma.isInstalled) ...[
                          ElevatedButton.icon(
                            onPressed: () => controller.openPhpMyAdmin(),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Buka phpMyAdmin di Browser (1-Klik)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'URL: http://127.0.0.1/__phpmyadmin/ • Login otomatis root tanpa password',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 11, fontFamily: 'Consolas'),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: () => controller.installSingleComponent('phpmyadmin'),
                            icon: const Icon(Icons.download, size: 18),
                            label: const Text('Install phpMyAdmin Sekarang'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentAmber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text('Informasi Koneksi Database', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildRow('Jenis Database', 'MySQL / MariaDB'),
                      const Divider(height: 20),
                      _buildRow('Server Host', '127.0.0.1'),
                      const Divider(height: 20),
                      _buildRow('Port', '3306'),
                      const Divider(height: 20),
                      _buildRow('User Default', 'root'),
                      const Divider(height: 20),
                      _buildRow('Password', '(Kosong)'),
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

  Widget _buildRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 160, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Consolas'))),
      ],
    );
  }
}
