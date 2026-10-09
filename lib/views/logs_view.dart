import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Developer Terminal Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Live Server Logs',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: Text(
                          '${controller.logs.length} Lines',
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
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: controller.logs.isEmpty
                            ? null
                            : () {
                                Clipboard.setData(ClipboardData(text: controller.logs.join('\n')));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Semua baris log disalin ke clipboard.'),
                                    backgroundColor: AppTheme.cardDark,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy_rounded, size: 13),
                        label: const Text('Salin Log', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          backgroundColor: AppTheme.surfaceSubtle,
                          side: const BorderSide(color: AppTheme.borderDark),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => controller.clearLogs(),
                        icon: const Icon(Icons.clear_all_rounded, size: 14),
                        label: const Text('Bersihkan', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          backgroundColor: AppTheme.surfaceSubtle,
                          side: const BorderSide(color: AppTheme.borderDark),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Console Terminal Body
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090B0F),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: controller.logs.isEmpty
                      ? const Center(
                          child: Text(
                            'Menunggu output aktivitas server...',
                            style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: AppTheme.monoFont),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: controller.logs.length,
                          itemBuilder: (context, index) {
                            final log = controller.logs[index];
                            Color textColor = const Color(0xFFCBD5E1);
                            if (log.contains('Error') || log.contains('Gagal') || log.contains('ERR')) {
                              textColor = AppTheme.accentRed;
                            } else if (log.contains('Berhasil') || log.contains('Running') || log.contains('Online')) {
                              textColor = AppTheme.accentGreen;
                            } else if (log.contains('Warning') || log.contains('Peringatan')) {
                              textColor = AppTheme.accentAmber;
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1.5),
                              child: Text(
                                log,
                                style: TextStyle(
                                  fontFamily: AppTheme.monoFont,
                                  fontSize: 11.5,
                                  color: textColor,
                                  height: 1.35,
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