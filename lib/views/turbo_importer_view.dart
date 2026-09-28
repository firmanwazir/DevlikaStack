import 'package:flutter/material.dart';
import '../services/mariadb_manager.dart';
import '../services/server_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/big_db_importer_widget.dart';

class TurboImporterView extends StatelessWidget {
  const TurboImporterView({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServerController.instance,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Turbo Engine Highlights Bar
              _buildEngineHeader(context),

              const SizedBox(height: 20),

              // 2. Main Importer Interactive Workspace
              const BigDbImporterWidget(),

              const SizedBox(height: 24),

              // 3. Technical Specs & Storage Architecture Guide
              _buildArchitectureGuide(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEngineHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentCyan.withOpacity(0.12),
            AppTheme.accentBlue.withOpacity(0.08),
            AppTheme.cardDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accentCyan, AppTheme.accentBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentCyan.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Big Database Turbo Importer Engine',
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
                        color: AppTheme.accentGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
                      ),
                      child: const Text(
                        'DUAL-ENGINE ACTIVE',
                        style: TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Pipeline streaming biner langsung ke MariaDB Client • 0 MB RAM Overflow • Anti Head-Thrashing HDD & 2000 IOPS SSD',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accentCyan.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _buildBadge(
            icon: Icons.storage_rounded,
            label: 'Port 3306',
            color: MariaDbManager.instance.isRunning ? AppTheme.accentGreen : AppTheme.accentRed,
          ),
          const SizedBox(width: 8),
          _buildBadge(
            icon: Icons.memory_rounded,
            label: '~15 MB RAM Flat',
            color: AppTheme.accentCyan,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureGuide(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildGuideCard(
                      icon: Icons.album_rounded,
                      iconColor: AppTheme.accentAmber,
                      title: 'Kehandalan Khusus HDD',
                      points: [
                        'Kluster baca sekuensial 1 MB memotong lompatan jarum mekanis (head seek) hingga 16x.',
                        'Mode safe commit (innodb_flush_log_at_trx_commit = 2) melompati batas 100 fsync/s piringan.',
                        'Buffer pool 512 MB menampung B-Tree index dan dirty pages di RAM.',
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildGuideCard(
                      icon: Icons.flash_on_rounded,
                      iconColor: AppTheme.accentCyan,
                      title: 'Akselerasi Penuh SSD',
                      points: [
                        'Membuka batas bawaan MySQL dengan kapasitas I/O paralel 1000 - 2000 IOPS.',
                        'Penyusunan indeks (sort & bulk insert) 64 MB langsung di RAM tanpa file sementara di disk.',
                        'Throughput streaming mencapai kecepatan penuh drive tanpa memory bottleneck.',
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildGuideCard(
                      icon: Icons.shield_rounded,
                      iconColor: AppTheme.accentGreen,
                      title: 'Proteksi File 2 GB+',
                      points: [
                        'Timeout koneksi diperpanjang otomatis hingga 1 jam (anti MySQL server gone away).',
                        'Dukungan data biner BLOB (--binary-mode) menjamin gambar & dokumen tidak korup.',
                        'Pencegahan crash InnoDB lock table size exceeded pada transaksi masif.',
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildGuideCard(
                    icon: Icons.album_rounded,
                    iconColor: AppTheme.accentAmber,
                    title: 'Kehandalan Khusus HDD',
                    points: [
                      'Kluster baca sekuensial 1 MB memotong lompatan jarum mekanis (head seek) hingga 16x.',
                      'Mode safe commit (innodb_flush_log_at_trx_commit = 2) melompati batas 100 fsync/s piringan.',
                      'Buffer pool 512 MB menampung B-Tree index dan dirty pages di RAM.',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuideCard(
                    icon: Icons.flash_on_rounded,
                    iconColor: AppTheme.accentCyan,
                    title: 'Akselerasi Penuh SSD',
                    points: [
                      'Membuka batas bawaan MySQL dengan kapasitas I/O paralel 1000 - 2000 IOPS.',
                      'Penyusunan indeks (sort & bulk insert) 64 MB langsung di RAM tanpa file sementara di disk.',
                      'Throughput streaming mencapai kecepatan penuh drive tanpa memory bottleneck.',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuideCard(
                    icon: Icons.shield_rounded,
                    iconColor: AppTheme.accentGreen,
                    title: 'Proteksi File 2 GB+',
                    points: [
                      'Timeout koneksi diperpanjang otomatis hingga 1 jam (anti MySQL server gone away).',
                      'Dukungan data biner BLOB (--binary-mode) menjamin gambar & dokumen tidak korup.',
                      'Pencegahan crash InnoDB lock table size exceeded pada transaksi masif.',
                    ],
                  ),
                ],
              );
      },
    );
  }

  Widget _buildGuideCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> points,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...points.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    Expanded(
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
