import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/server_controller.dart';
import '../services/port_checker_service.dart';

class PortSettingsDialog extends StatefulWidget {
  const PortSettingsDialog({super.key});

  @override
  State<PortSettingsDialog> createState() => _PortSettingsDialogState();
}

class _PortSettingsDialogState extends State<PortSettingsDialog> {
  late final TextEditingController _httpController;
  late final TextEditingController _httpsController;
  late final TextEditingController _mariaDbController;

  bool _isChecking = false;
  PortStatus? _httpStatus;
  PortStatus? _mariaDbStatus;

  @override
  void initState() {
    super.initState();
    final controller = ServerController.instance;
    _httpController = TextEditingController(text: controller.httpPort.toString());
    _httpsController = TextEditingController(text: controller.httpsPort.toString());
    _mariaDbController = TextEditingController(text: controller.mariaDbPort.toString());
    _checkPorts();
  }

  @override
  void dispose() {
    _httpController.dispose();
    _httpsController.dispose();
    _mariaDbController.dispose();
    super.dispose();
  }

  Future<void> _checkPorts() async {
    setState(() => _isChecking = true);
    final httpPort = int.tryParse(_httpController.text) ?? 80;
    final mariaDbPort = int.tryParse(_mariaDbController.text) ?? 3306;

    final httpStatus = await PortCheckerService.instance.checkPort(httpPort);
    final mariaDbStatus = await PortCheckerService.instance.checkPort(mariaDbPort);

    if (mounted) {
      setState(() {
        _httpStatus = httpStatus;
        _mariaDbStatus = mariaDbStatus;
        _isChecking = false;
      });
    }
  }

  Future<void> _save() async {
    final http = int.tryParse(_httpController.text.trim());
    final https = int.tryParse(_httpsController.text.trim());
    final mariaDb = int.tryParse(_mariaDbController.text.trim());

    if (http == null || http <= 0 || http > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port HTTP harus antara 1 dan 65535')),
      );
      return;
    }
    if (https == null || https <= 0 || https > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port HTTPS harus antara 1 dan 65535')),
      );
      return;
    }
    if (mariaDb == null || mariaDb <= 0 || mariaDb > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Port MariaDB harus antara 1 dan 65535')),
      );
      return;
    }

    final controller = ServerController.instance;
    await controller.setHttpPort(http);
    await controller.setHttpsPort(https);
    await controller.setMariaDbPort(mariaDb);

    if (mounted) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Port berhasil diperbarui: HTTP $http, HTTPS $https, MariaDB $mariaDb'),
          backgroundColor: AppTheme.accentGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: const Icon(
                    Icons.lan_outlined,
                    color: AppTheme.accentIndigo,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konfigurasi Port Jaringan',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sesuaikan port agar tidak bentrok dengan XAMPP, IIS, atau server lain.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isChecking)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentIndigo),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Tip Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.accentCyan),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gunakan port 8080 (HTTP) dan 3307 (MariaDB) jika Anda ingin menjalankan DevlikaStack berdampingan dengan XAMPP.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 1. HTTP Port
            _buildPortField(
              label: 'Port Web HTTP',
              controller: _httpController,
              status: _httpStatus,
              isServerRunning: ServerController.instance.isWebRunning,
              currentConfiguredPort: ServerController.instance.httpPort,
              presets: const [
                {'port': '80', 'label': '80 (Default)'},
                {'port': '8080', 'label': '8080 (XAMPP)'},
                {'port': '8000', 'label': '8000'},
              ],
              onChanged: () => _checkPorts(),
            ),
            const SizedBox(height: 14),

            // 2. HTTPS Port
            _buildSimplePortField(
              label: 'Port Web HTTPS (SSL)',
              controller: _httpsController,
              presets: const [
                {'port': '443', 'label': '443 (Default)'},
                {'port': '8443', 'label': '8443 (Alt)'},
              ],
            ),
            const SizedBox(height: 14),

            // 3. MariaDB Port
            _buildPortField(
              label: 'Port MariaDB (MySQL)',
              controller: _mariaDbController,
              status: _mariaDbStatus,
              isServerRunning: ServerController.instance.isMariaDbRunning,
              currentConfiguredPort: ServerController.instance.mariaDbPort,
              presets: const [
                {'port': '3306', 'label': '3306 (Default)'},
                {'port': '3307', 'label': '3307 (XAMPP)'},
                {'port': '3308', 'label': '3308'},
              ],
              onChanged: () => _checkPorts(),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderDark),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentIndigo,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Simpan & Terapkan', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortField({
    required String label,
    required TextEditingController controller,
    required PortStatus? status,
    required bool isServerRunning,
    required int currentConfiguredPort,
    required List<Map<String, String>> presets,
    required VoidCallback onChanged,
  }) {
    final currentInput = int.tryParse(controller.text) ?? 0;
    final isOurOwnServer = isServerRunning && (currentInput == currentConfiguredPort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (status != null)
              _buildStatusBadge(status, isOurOwnServer),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 120,
              height: 36,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => onChanged(),
                style: const TextStyle(
                  fontFamily: AppTheme.monoFont,
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.accentIndigo),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                children: presets.map((p) {
                  final isSelected = controller.text == p['port'];
                  return InkWell(
                    onTap: () {
                      controller.text = p['port']!;
                      onChanged();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1E2330) : AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? AppTheme.accentIndigo : AppTheme.borderDark,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        p['label']!,
                        style: TextStyle(
                          fontFamily: AppTheme.monoFont,
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSimplePortField({
    required String label,
    required TextEditingController controller,
    required List<Map<String, String>> presets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 120,
              height: 36,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontFamily: AppTheme.monoFont,
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: AppTheme.bgDark,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderDark),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.borderDark),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: AppTheme.accentIndigo),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 6,
              children: presets.map((p) {
                final isSelected = controller.text == p['port'];
                return InkWell(
                  onTap: () {
                    setState(() {
                      controller.text = p['port']!;
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E2330) : AppTheme.surfaceSubtle,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? AppTheme.accentIndigo : AppTheme.borderDark,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      p['label']!,
                      style: TextStyle(
                        fontFamily: AppTheme.monoFont,
                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(PortStatus status, bool isOurOwnServer) {
    if (isOurOwnServer) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 11, color: AppTheme.accentGreen),
            SizedBox(width: 4),
            Text(
              'Aktif (DevlikaStack)',
              style: TextStyle(color: AppTheme.accentGreen, fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (status.isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 11, color: AppTheme.accentGreen),
            SizedBox(width: 4),
            Text(
              'Tersedia',
              style: TextStyle(color: AppTheme.accentGreen, fontSize: 10.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    // Occupied
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 11, color: AppTheme.accentAmber),
          const SizedBox(width: 4),
          Text(
            status.description,
            style: const TextStyle(color: AppTheme.accentAmber, fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
