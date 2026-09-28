import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/site_model.dart';
import '../services/tunnel_service.dart';
import '../theme/app_theme.dart';

class TunnelDialog extends StatelessWidget {
  final SiteModel? site;
  final String? customDomain;
  final int localPort;

  const TunnelDialog({
    super.key,
    this.site,
    this.customDomain,
    this.localPort = 80,
  });

  String get targetDomain => site?.domain ?? customDomain ?? 'localhost';

  @override
  Widget build(BuildContext context) {
    final tunnel = TunnelService.instance;

    return AnimatedBuilder(
      animation: tunnel,
      builder: (context, _) {
        final isRunningOnThis =
            tunnel.isRunning && tunnel.activeDomain == targetDomain;
        final isConnectingOnThis =
            tunnel.isStarting && tunnel.activeDomain == targetDomain;

        return Dialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.3)),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_rounded,
                        color: AppTheme.accentPurple,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cloudflare Quick Tunnel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bagikan website lokal ke internet secara aman untuk preview klien.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Target Site Info Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDark.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.language_rounded, size: 16, color: AppTheme.accentCyan),
                      const SizedBox(width: 8),
                      Text(
                        'Target Host: ',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                      Text(
                        targetDomain,
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Consolas',
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Port $localPort',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Content based on states: Downloading / Not Installed / Connecting / Live / Idle
                if (tunnel.isDownloading) ...[
                  _buildDownloadingState(tunnel),
                ] else if (!tunnel.isInstalled) ...[
                  _buildInstallRequiredState(context, tunnel),
                ] else if (isConnectingOnThis) ...[
                  _buildConnectingState(),
                ] else if (isRunningOnThis && tunnel.publicUrl != null) ...[
                  _buildLiveTunnelState(context, tunnel),
                ] else ...[
                  _buildIdleState(context, tunnel),
                ],

                if (tunnel.lastError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 18),
                        const SizedBox(width: 10),
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
      },
    );
  }

  Widget _buildDownloadingState(TunnelService tunnel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tunnel.downloadStatus,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: tunnel.downloadProgress > 0 ? tunnel.downloadProgress : null,
              backgroundColor: AppTheme.borderDark,
              color: AppTheme.accentBlue,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallRequiredState(BuildContext context, TunnelService tunnel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Komponen cloudflared Diperlukan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Fitur ini membutuhkan binary resmi Cloudflare Tunnel (~55 MB). Hanya perlu diunduh satu kali dan langsung siap digunakan tanpa akun.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Unduh cloudflared Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => tunnel.downloadCloudflared(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingState() {
    return Container(
      padding: const EdgeInsets.all(20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.bgDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: const [
          CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.accentPurple),
          SizedBox(height: 14),
          Text(
            'Menghubungkan ke Cloudflare Edge Network...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          SizedBox(height: 4),
          Text(
            'Membuat rute HTTPS publik yang aman untuk klien Anda.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTunnelState(BuildContext context, TunnelService tunnel) {
    final url = tunnel.publicUrl!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen,
                boxShadow: [
                  BoxShadow(color: AppTheme.accentGreen, blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ONLINE & SECURE (HTTPS AKTIF)',
              style: TextStyle(
                color: AppTheme.accentGreen,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Public URL Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.accentGreen.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_rounded, size: 16, color: AppTheme.accentGreen),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  url,
                  style: const TextStyle(
                    fontFamily: 'Consolas',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.accentGreen),
                tooltip: 'Salin Tautan',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tautan berhasil disalin: $url'),
                      backgroundColor: AppTheme.accentGreen,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Feature Notes
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.verified_rounded, size: 14, color: AppTheme.accentCyan),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tautan ini aman dengan sertifikat SSL resmi Cloudflare. Klien dapat membukanya langsung di smartphone atau browser mana pun tanpa peringatan sertifikat.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                label: const Text('Buka di Browser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.borderDark),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => launchUrl(Uri.parse(url)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stop_rounded, size: 16),
                label: const Text('Hentikan Tunnel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => tunnel.stopTunnel(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIdleState(BuildContext context, TunnelService tunnel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Publikasikan Website Ini ke Klien Secara Instan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        const Text(
          'Cloudflare Quick Tunnel akan membuat URL publik terenkripsi (HTTPS) otomatis ke server lokal ini. Sangat cocok untuk demo dan pengujian responsif bersama klien.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Mulai Online Tunnel (1-Klik)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              tunnel.startTunnel(domain: targetDomain, localPort: localPort);
            },
          ),
        ),
      ],
    );
  }
}
