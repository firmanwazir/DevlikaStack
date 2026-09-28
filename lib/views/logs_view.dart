import 'package:flutter/material.dart';
import '../services/server_controller.dart';
import '../theme/app_theme.dart';

class LogsView extends StatefulWidget {
  const LogsView({super.key});

  @override
  State<LogsView> createState() => _LogsViewState();
}

class _LogsViewState extends State<LogsView> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScrollEnabled = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final isNearBottom = _scrollController.position.maxScrollExtent -
                _scrollController.offset <
            80;
        _autoScrollEnabled = isNearBottom;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_autoScrollEnabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ServerController.instance.logsNotifier,
      builder: (context, _) {
        final controller = ServerController.instance;
        _scrollToBottom();

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Log Aktivitas Real-Time',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => controller.clearLogs(),
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Bersihkan Log'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: controller.logs.isEmpty
                      ? const Center(
                          child: Text(
                            'Belum ada log aktivitas...',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontFamily: 'Consolas'),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: controller.logs.length,
                          itemBuilder: (context, index) {
                            final log = controller.logs[index];
                            Color textColor = AppTheme.accentCyan;
                            if (log.contains('Error') || log.contains('Gagal')) {
                              textColor = AppTheme.accentRed;
                            } else if (log.contains('MariaDB')) {
                              textColor = AppTheme.accentGreen;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                log,
                                style: TextStyle(
                                  fontFamily: 'Consolas',
                                  fontSize: 12,
                                  color: textColor,
                                  height: 1.4,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
