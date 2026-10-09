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
        final isRunning = MariaDbManager.instance.isRunning;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Importer Header Module
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderDark),
                ),
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
                      child: const Icon(Icons.bolt_rounded, color: AppTheme.textPrimary, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Database SQL Importer',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppTheme.borderDark),
                                ),
                                child: const Text(
                                  'CLI STREAMING',
                                  style: TextStyle(
                                    fontFamily: AppTheme.monoFont,
                                    color: AppTheme.textSecondary,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Import database dump SQL besar langsung via binary client MariaDB tanpa batasan memory limit PHP.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRunning ? AppTheme.accentGreen.withOpacity(0.08) : AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isRunning ? AppTheme.accentGreen.withOpacity(0.3) : AppTheme.borderDark,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Port 3306',
                            style: TextStyle(
                              fontFamily: AppTheme.monoFont,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isRunning ? AppTheme.accentGreen : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Main Importer Interactive Workspace
              const BigDbImporterWidget(),

              const SizedBox(height: 14),

              // 3. Technical Architecture Cards
              _buildArchitectureGuide(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArchitectureGuide(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 850;
        final cards = [
          _buildGuideCard(
            title: 'Optimasi I/O Buffer',
            points: [
              'Buffer pembacaan sekuensial untuk meminimalkan latensi disk.',
              'Transaksi efisien dengan innodb_flush_log_at_trx_commit = 2.',
              'Buffer pool memadai untuk penulisan indeks dan halaman data.',
            ],
          ),
          _buildGuideCard(
            title: 'Performa Database Langsung',
            points: [
              'Eksekusi batch query langsung ke socket MariaDB lokal.',
              'Alokasi memory sementara dioptimalkan untuk bulk insert.',
              'Throughput streaming stabil tanpa bottleneck parsing skrip.',
            ],
          ),
          _buildGuideCard(
            title: 'Integritas & Keamanan Data',
            points: [
              'Timeout koneksi dinamis untuk menangani file SQL multi-gigabyte.',
              'Dukungan penuh mode biner (--binary-mode) untuk data BLOB.',
              'Penanganan error presisi dengan rollback transaksi bertahap.',
            ],
          ),
        ];

        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }

  Widget _buildGuideCard({
    required String title,
    required List<String> points,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...points.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('– ', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                  Expanded(
                    child: Text(
                      p,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.textMuted,
                        height: 1.35,
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
  }
}
