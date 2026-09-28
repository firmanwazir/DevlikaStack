import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/server_controller.dart';

class HeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;

  const HeaderBar({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServerController.instance,
      builder: (context, _) {
        final controller = ServerController.instance;
        final isAllRunning = controller.isWebRunning && controller.isMariaDbRunning;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: AppTheme.cardDark,
            border: Border(
              bottom: BorderSide(color: AppTheme.borderDark, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Page Titles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Quick Status Chips
              _buildPortChip('Web: 80', controller.isWebRunning),
              const SizedBox(width: 8),
              _buildPortChip('DB: 3306', controller.isMariaDbRunning),
              const SizedBox(width: 16),

              // phpMyAdmin Quick Link
              OutlinedButton.icon(
                onPressed: () => controller.openPhpMyAdmin(),
                icon: const Icon(Icons.table_chart_rounded, size: 16),
                label: const Text('phpMyAdmin'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentCyan,
                  side: const BorderSide(color: AppTheme.borderDark),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),

              // Master Start / Stop Button
              ElevatedButton.icon(
                onPressed: () {
                  if (isAllRunning) {
                    controller.stopAll();
                  } else {
                    controller.startAll();
                  }
                },
                icon: Icon(
                  isAllRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(
                  isAllRunning ? 'Stop All' : 'Start All',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAllRunning ? AppTheme.accentRed : AppTheme.accentGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortChip(String label, bool isRunning) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isRunning
            ? AppTheme.accentGreen.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        border: Border.all(
          color: isRunning
              ? AppTheme.accentGreen.withOpacity(0.3)
              : AppTheme.borderDark,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRunning ? AppTheme.accentGreen : AppTheme.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isRunning ? AppTheme.accentGreen : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
