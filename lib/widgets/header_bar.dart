import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/server_controller.dart';
import 'port_settings_dialog.dart';

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.bgDark,
            border: Border(
              bottom: BorderSide(color: AppTheme.borderDark, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Page Title & Concise Breadcrumb
              Expanded(
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 1,
                      height: 12,
                      color: AppTheme.borderDark,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Technical Status Chips (Monospace & Compact, Interactive)
              InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => const PortSettingsDialog(),
                ),
                borderRadius: BorderRadius.circular(4),
                child: _buildPortPill('HTTP: ${controller.httpPort}', controller.isWebRunning),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => const PortSettingsDialog(),
                ),
                borderRadius: BorderRadius.circular(4),
                child: _buildPortPill('DB: ${controller.mariaDbPort}', controller.isMariaDbRunning),
              ),
              const SizedBox(width: 12),

              // phpMyAdmin Quick Link (Clean Outlined)
              OutlinedButton.icon(
                onPressed: () => controller.openPhpMyAdmin(),
                icon: const Icon(Icons.table_view_outlined, size: 14, color: AppTheme.textSecondary),
                label: const Text('phpMyAdmin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  backgroundColor: AppTheme.cardDark,
                  side: const BorderSide(color: AppTheme.borderDark),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Master Action Button with lightweight animation & busy indicator
              ElevatedButton.icon(
                onPressed: controller.isOperatingAll
                    ? null
                    : () {
                        if (isAllRunning) {
                          controller.stopAll();
                        } else {
                          controller.startAll();
                        }
                      },
                icon: controller.isOperatingAll
                    ? const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isAllRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                label: Text(
                  controller.isStartingAll
                      ? 'Memulai...'
                      : controller.isStoppingAll
                          ? 'Menghentikan...'
                          : (isAllRunning ? 'Stop All' : 'Start All'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: controller.isStoppingAll || (isAllRunning && !controller.isStartingAll)
                      ? const Color(0xFFBE123C)
                      : const Color(0xFF047857),
                  disabledBackgroundColor: controller.isStoppingAll || isAllRunning
                      ? const Color(0xFFBE123C).withOpacity(0.7)
                      : const Color(0xFF047857).withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortPill(String label, bool isRunning) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isRunning
            ? AppTheme.accentGreen.withOpacity(0.08)
            : AppTheme.surfaceSubtle,
        border: Border.all(
          color: isRunning
              ? AppTheme.accentGreen.withOpacity(0.25)
              : AppTheme.borderDark,
        ),
        borderRadius: BorderRadius.circular(5),
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
            label,
            style: TextStyle(
              fontFamily: AppTheme.monoFont,
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
