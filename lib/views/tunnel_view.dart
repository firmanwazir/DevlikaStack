import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/site_model.dart';
import '../services/server_controller.dart';
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
  final TextEditingController _portController = TextEditingController(text: '80');
  final ScrollController _logScrollController = ScrollController();
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    final sites = ServerController.instance.sites;
    if (sites.isNotEmpty) {
      _selectedDomain = sites.first.domain;
    }

    TunnelService.instance.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
          if (_logs.length > 300) _logs.removeAt(0);
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header Banner
              _buildHeaderBanner(context, tunnel),

              const SizedBox(height: 20),

              // 2. Main Control & Preview Card
              _buildMainControlCard(context, tunnel),

              const SizedBox(height: 24),

              // 3. Live Log Terminal & Features Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildLogTerminal(context)),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: _buildFeatureGuide(context)),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accentPurple.withOpacity(0.12),
            AppTheme.accentCyan.withOpacity(0.08),
            AppTheme.cardDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRunning
              ? AppTheme.accentGreen.withOpacity(0.4)
              : AppTheme.accentPurple.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isRunning
                    ? [AppTheme.accentGreen, AppTheme.accentCyan]
                    : [AppTheme.accentPurple, AppTheme.accentBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isRunning ? AppTheme.accentGreen : AppTheme.accentPurple).withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              isRunning ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
              color: Colors.white,
              size: 26,
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
                      'Cloudflare Quick Tunnel (Preview Online)',
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
                        color: isRunning
                            ? AppTheme.accentGreen.withOpacity(0.15)
                            : (tunnel.isStarting
                                ? AppTheme.accentAmber.withOpacity(0.15)
                                : AppTheme.textMuted.withOpacity(0.15)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isRunning
                              ? AppTheme.accentGreen.withOpacity(0.4)
                              : (tunnel.isStarting
                                  ? AppTheme.accentAmber.withOpacity(0.4)
                                  : AppTheme.borderDark),
                        ),
                      ),
                      child: Text(
                        isRunning
                            ? 'ONLINE PREVIEW AKTIF'
                            : (tunnel.isStarting ? 'CONNECTING...' : 'OFFLINE'),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isRunning
                              ? AppTheme.accentGreen
                              : (tunnel.isStarting ? AppTheme.accentAmber : AppTheme.textMuted),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Publikasikan website lokal ke internet secara instan tanpa perlu IP publik atau konfigurasi router port-forwarding.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isRunning) ...[
            ElevatedButton.icon(
              onPressed: _stopTunnel,
              icon: const Icon(Icons.stop_circle_outlined, size: 16),
              label: const Text('Hentikan Tunnel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

    return Card(
      elevation: 0,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target Selection Header
            Row(
              children: [
                const Icon(Icons.tune_rounded, size: 18, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                const Text(
                  'Konfigurasi Target Preview',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Mode Toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'vhost',
                      label: Text('Virtual Host', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.language_rounded, size: 14),
                    ),
                    ButtonSegment(
                      value: 'port',
                      label: Text('Port Kustom', style: TextStyle(fontSize: 12)),
                      icon: Icon(Icons.numbers_rounded, size: 14),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: isRunning || isStarting
                      ? null
                      : (newVal) => setState(() => _selectedMode = newVal.first),
                  style: SegmentedButton.styleFrom(
                    backgroundColor: AppTheme.bgDark,
                    selectedBackgroundColor: AppTheme.accentPurple.withOpacity(0.2),
                    selectedForegroundColor: AppTheme.accentPurple,
                    foregroundColor: AppTheme.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Selectors row
            Row(
              children: [
                if (_selectedMode == 'vhost') ...[
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pilih Virtual Host Lokal',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.bgDark,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderDark),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: sites.any((s) => s.domain == _selectedDomain)
                                  ? _selectedDomain
                                  : (sites.isNotEmpty ? sites.first.domain : null),
                              dropdownColor: AppTheme.bgCard,
                              hint: const Text('Belum ada host', style: TextStyle(color: AppTheme.textMuted)),
                              items: sites.map((s) {
                                return DropdownMenuItem<String>(
                                  value: s.domain,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.language_rounded, size: 15, color: AppTheme.accentCyan),
                                      const SizedBox(width: 8),
                                      Text(
                                        s.domain,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Consolas',
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
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
                  const SizedBox(width: 16),
                ],

                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Port Lokal',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _portController,
                        enabled: !isRunning && !isStarting,
                        style: const TextStyle(color: Colors.white, fontFamily: 'Consolas', fontSize: 13),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.tag_rounded, size: 16, color: AppTheme.textMuted),
                          filled: true,
                          fillColor: AppTheme.bgDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderDark),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderDark),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Action Button
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Eksekusi', style: TextStyle(color: Colors.transparent, fontSize: 12)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: !tunnel.isInstalled
                            ? ElevatedButton.icon(
                                onPressed: isDownloading
                                    ? null
                                    : () => tunnel.downloadCloudflared(),
                                icon: isDownloading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.download_rounded, size: 18),
                                label: Text(
                                  isDownloading ? 'Mengunduh...' : 'Unduh Cloudflared (~55MB)',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentPurple,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: isDownloading
                                    ? null
                                    : (isRunning
                                        ? _stopTunnel
                                        : (isStarting ? null : _startTunnel)),
                                icon: isStarting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Icon(
                                        isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                        size: 20,
                                      ),
                                label: Text(
                                  isRunning
                                      ? 'Hentikan Preview'
                                      : (isStarting ? 'Menghubungkan...' : 'Mulai Tunnel Preview'),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isRunning ? AppTheme.accentRed : AppTheme.accentGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.borderDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tunnel.downloadStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Text(
                          '${(tunnel.downloadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: AppTheme.accentPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: tunnel.downloadProgress,
                      backgroundColor: AppTheme.borderDark,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentPurple),
                      minHeight: 6,
                    ),
                  ],
                ),
              ),
            ],

            // Active Online Box
            if (isRunning && tunnel.publicUrl != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.accentGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.accentGreen.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.accentGreen,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentGreen.withOpacity(0.8),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Link Preview Publik Siap Dibagikan ke Klien:',
                          style: TextStyle(
                            color: AppTheme.accentGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Target: ${tunnel.activeDomain} (${tunnel.activePort})',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontFamily: 'Consolas',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.bgDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.accentGreen.withOpacity(0.4)),
                            ),
                            child: SelectableText(
                              tunnel.publicUrl!,
                              style: const TextStyle(
                                color: AppTheme.accentCyan,
                                fontFamily: 'Consolas',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: tunnel.publicUrl!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Link preview publik disalin ke clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Salin Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(tunnel.publicUrl!);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Buka Preview'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.accentCyan,
                            side: const BorderSide(color: AppTheme.accentCyan),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Error Message
            if (tunnel.lastError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accentRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.accentRed),
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
      ),
    );
  }

  Widget _buildLogTerminal(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal_rounded, size: 18, color: AppTheme.accentCyan),
                const SizedBox(width: 8),
                const Text(
                  'Log Aktivitas Tunnel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all_rounded, size: 18, color: AppTheme.textMuted),
                  tooltip: 'Bersihkan Log',
                  onPressed: () => setState(() => _logs.clear()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 220,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        'Menunggu proses tunnel dimulai...',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12, fontFamily: 'Consolas'),
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
                              fontFamily: 'Consolas',
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGuide(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppTheme.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.borderDark),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.verified_rounded, size: 18, color: AppTheme.accentPurple),
                SizedBox(width: 8),
                Text(
                  'Keunggulan Cloudflare Tunnel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              icon: Icons.lock_rounded,
              color: AppTheme.accentGreen,
              title: 'Sertifikat SSL Resmi Valid',
              desc: 'Browser klien tidak akan menampilkan peringatan keamanan merah karena sertifikat diterbitkan langsung oleh Cloudflare CA.',
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.all_inclusive_rounded,
              color: AppTheme.accentCyan,
              title: '100% Gratis & Unlimited',
              desc: 'Tidak ada batasan bandwidth preview bulanan seperti di ngrok atau layanan tunnel berbayar lainnya.',
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.no_accounts_rounded,
              color: AppTheme.accentAmber,
              title: 'Tanpa Registrasi Akun',
              desc: 'Fitur Quick Tunnel langsung aktif tanpa perlu login, auth token, atau pembuatan akun Cloudflare.',
            ),
            const SizedBox(height: 12),
            _buildFeatureItem(
              icon: Icons.security_rounded,
              color: AppTheme.accentPurple,
              title: 'Aman & Terisolasi',
              desc: 'Koneksi keluar (outbound tunnel) terenkripsi, router Anda tidak perlu membuka port berbahaya ke publik.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
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
