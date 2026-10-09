import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/site_model.dart';
import '../services/server_controller.dart';
import '../services/config_service.dart';
import '../services/tunnel_service.dart';
import '../theme/app_theme.dart';

class TunnelView extends StatefulWidget {
  const TunnelView({super.key});

  @override
  State<TunnelView> createState() => _TunnelViewState();
}

class _TunnelViewState extends State<TunnelView> {
  String _selectedMode = 'vhost'; // 'vhost' or 'port'
  String? _selectedDomain;
  late final TextEditingController _portController;
  final ScrollController _logScrollController = ScrollController();
  final List<String> _logs = [];
  StreamSubscription<String>? _logSub;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: ConfigService.instance.httpPort.toString());
    final sites = ServerController.instance.sites;
    if (sites.isNotEmpty) {
      _selectedDomain = sites.first.domain;
    }

    _logSub = TunnelService.instance.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          if (_logs.length > 500) _logs.removeRange(0, _logs.length - 500);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
              _logScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _portController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }

  Future<void> _startTunnel() async {
    final tunnel = TunnelService.instance;
    final port = int.tryParse(_portController.text.trim()) ?? 80;
    final domain = _selectedMode == 'vhost' ? (_selectedDomain ?? 'localhost') : 'localhost';

    await tunnel.startTunnel(domain: domain, localPort: port);
  }

  Future<void> _stopTunnel() async {
    await TunnelService.instance.stopTunnel();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([TunnelService.instance, ServerController.instance]),
      builder: (context, _) {
        final tunnel = TunnelService.instance;
        final isRunning = tunnel.isRunning;
        final isStarting = tunnel.isStarting;
        final isDownloading = tunnel.isDownloading;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header Banner
              _buildHeaderBanner(context, tunnel),

              const SizedBox(height: 14),

              // 2. Main Control & Preview Card
              _buildMainControlCard(context, tunnel),

              const SizedBox(height: 14),

              // 3. Live Log Terminal & Features Card
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: _buildLogTerminal(context)),
                            const SizedBox(width: 14),
                            Expanded(flex: 2, child: _buildFeatureGuide(context)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildMainControlCard(context, tunnel),
                            const SizedBox(height: 14),
                            _buildFeatureGuide(context),
                          ],
                        );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeaderBanner(BuildContext context, TunnelService tunnel) {
    final isRunning = tunnel.isRunning;

    return Container(
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
            child: Icon(
              isRunning ? Icons.cloud_done_rounded : Icons.cloud_outlined,
              color: isRunning ? AppTheme.accentGreen : AppTheme.textPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Cloudflare Quick Tunnel (Online Preview)',
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
                        color: isRunning
                            ? AppTheme.accentGreen.withOpacity(0.1)
                            : (tunnel.isStarting ? AppTheme.accentAmber.withOpacity(0.1) : AppTheme.surfaceSubtle),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isRunning
                              ? AppTheme.accentGreen.withOpacity(0.3)
                              : (tunnel.isStarting ? AppTheme.accentAmber.withOpacity(0.3) : AppTheme.borderDark),
                        ),
                      ),
                      child: Text(
                        isRunning
                            ? 'ONLINE'
                            : (tunnel.isStarting ? 'CONNECTING...' : 'OFFLINE'),
                        style: TextStyle(
                          fontFamily: AppTheme.monoFont,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: isRunning
                              ? AppTheme.accentGreen
                              : (tunnel.isStarting ? AppTheme.accentAmber : AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Publikasikan virtual host lokal ke internet secara aman dengan sertifikat SSL resmi.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          if (isRunning) ...[
            ElevatedButton.icon(
              onPressed: _stopTunnel,
              icon: const Icon(Icons.stop_rounded, size: 15, color: Colors.white),
              label: const Text('Hentikan Preview', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBE123C),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMainControlCard(BuildContext context, TunnelService tunnel) {
    final sites = ServerController.instance.sites;
    final isRunning = tunnel.isRunning;
    final isStarting = tunnel.isStarting;
    final isDownloading = tunnel.isDownloading;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Target Preview',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'vhost',
                    label: Text('Virtual Host', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.public, size: 13),
                  ),
                  ButtonSegment(
                    value: 'port',
                    label: Text('Port Kustom', style: TextStyle(fontSize: 11)),
                    icon: Icon(Icons.numbers_rounded, size: 13),
                  ),
                ],
                selected: {_selectedMode},
                onSelectionChanged: isRunning || isStarting
                    ? null
                    : (newVal) => setState(() => _selectedMode = newVal.first),
                style: SegmentedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceSubtle,
                  selectedBackgroundColor: const Color(0xFF1E2330),
                  selectedForegroundColor: AppTheme.textPrimary,
                  foregroundColor: AppTheme.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: const BorderSide(color: AppTheme.borderDark),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Selectors row
          Row(
            children: [
              if (_selectedMode == 'vhost') ...[
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pilih Domain Virtual Host', style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: sites.any((s) => s.domain == _selectedDomain)
                                ? _selectedDomain
                                : (sites.isNotEmpty ? sites.first.domain : null),
                            dropdownColor: AppTheme.cardDark,
                            hint: const Text('Belum ada host', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            items: sites.map((s) {
                              return DropdownMenuItem<String>(
                                value: s.domain,
                                child: Row(
                                  children: [
                                    const Icon(Icons.public, size: 14, color: AppTheme.textMuted),
                                    const SizedBox(width: 8),
                                    Text(
                                      s.domain,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontFamily: AppTheme.monoFont,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${s.type == 'proxy' ? 'Proxy :${s.proxyPort}' : s.phpVersion})',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: isRunning || isStarting
                                ? null
                                : (val) => setState(() => _selectedDomain = val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],

              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Port Server', style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _portController,
                        enabled: !isRunning && !isStarting,
                        style: const TextStyle(color: AppTheme.textPrimary, fontFamily: AppTheme.monoFont, fontSize: 12.5),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppTheme.surfaceSubtle,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppTheme.borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: const BorderSide(color: AppTheme.borderDark),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Action Button
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('', style: TextStyle(fontSize: 11.5)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      width: double.infinity,
                      child: !tunnel.isInstalled
                          ? ElevatedButton.icon(
                              onPressed: isDownloading ? null : () => tunnel.downloadCloudflared(),
                              icon: isDownloading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.download_rounded, size: 15),
                              label: Text(
                                isDownloading ? 'Mengunduh...' : 'Unduh cloudflared (~55MB)',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentIndigo,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: isDownloading
                                  ? null
                                  : (isRunning ? _stopTunnel : (isStarting ? null : _startTunnel)),
                              icon: isStarting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 16),
                              label: Text(
                                isRunning
                                    ? 'Hentikan Preview'
                                    : (isStarting ? 'Menghubungkan...' : 'Mulai Tunnel Preview'),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRunning ? const Color(0xFFBE123C) : const Color(0xFF047857),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                elevation: 0,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Download Progress Bar
          if (isDownloading) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tunnel.downloadStatus, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
                      Text(
                        '${(tunnel.downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontFamily: AppTheme.monoFont,
                          color: AppTheme.accentIndigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: tunnel.downloadProgress,
                    backgroundColor: AppTheme.borderDark,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentIndigo),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          ],

          // Active Online Public Link Box
          if (isRunning && tunnel.publicUrl != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentGreen),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Link Preview Publik Siap Dibagikan ke Klien:',
                        style: TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Target: ${tunnel.activeDomain} (:${tunnel.activePort})',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontFamily: AppTheme.monoFont,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.bgDark,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: SelectableText(
                            tunnel.publicUrl!,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontFamily: AppTheme.monoFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: tunnel.publicUrl!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Link preview publik disalin ke clipboard!'),
                              backgroundColor: AppTheme.cardDark,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Salin', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          backgroundColor: AppTheme.cardDark,
                          side: const BorderSide(color: AppTheme.borderDark),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(tunnel.publicUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('Buka', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          backgroundColor: AppTheme.cardDark,
                          side: const BorderSide(color: AppTheme.borderDark),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Auto-Reconnect Toggle
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.sync_rounded, size: 15, color: AppTheme.textMuted),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Auto-Reconnect jika koneksi tunnel terputus',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: tunnel.autoReconnectEnabled,
                  activeColor: AppTheme.accentGreen,
                  onChanged: (val) => tunnel.setAutoReconnect(val),
                ),
              ),
            ],
          ),

          // Error / Status Message
          if (tunnel.lastError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 15, color: AppTheme.accentRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tunnel.lastError!,
                      style: const TextStyle(color: AppTheme.accentRed, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogTerminal(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Log Terminal Cloudflare',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppTheme.textMuted),
                splashRadius: 15,
                tooltip: 'Bersihkan Log',
                onPressed: () => setState(() => _logs.clear()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 200,
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSubtle,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Menunggu proses tunnel dimulai...',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5, fontFamily: AppTheme.monoFont),
                    ),
                  )
                : ListView.builder(
                    controller: _logScrollController,
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          _logs[i],
                          style: TextStyle(
                            color: _logs[i].contains('error') || _logs[i].contains('ERR')
                                ? AppTheme.accentRed
                                : (_logs[i].contains('Online preview') || _logs[i].contains('trycloudflare.com')
                                    ? AppTheme.accentGreen
                                    : AppTheme.textSecondary),
                            fontFamily: AppTheme.monoFont,
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGuide(BuildContext context) {
    return Container(
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
            'Informasi & Keamanan Tunnel',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _buildFeatureItem(
            icon: Icons.lock_outline_rounded,
            title: 'Sertifikat SSL Resmi Valid',
            desc: 'Browser klien aman tanpa peringatan keamanan merah karena sertifikat diterbitkan langsung oleh Cloudflare CA.',
          ),
          const SizedBox(height: 10),
          _buildFeatureItem(
            icon: Icons.all_inclusive_rounded,
            title: '100% Gratis & Unlimited',
            desc: 'Tidak ada batasan kuota bandwidth preview bulanan seperti pada ngrok versi gratis.',
          ),
          const SizedBox(height: 10),
          _buildFeatureItem(
            icon: Icons.no_accounts_rounded,
            title: 'Tanpa Registrasi Akun',
            desc: 'Quick Tunnel langsung aktif tanpa memerlukan pembuatan akun atau auth token.',
          ),
          const SizedBox(height: 10),
          _buildFeatureItem(
            icon: Icons.shield_outlined,
            title: 'Aman & Terenkripsi',
            desc: 'Koneksi keluar (outbound tunnel) terenkripsi, router Anda tidak perlu membuka port publik.',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Icon(icon, size: 14, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
