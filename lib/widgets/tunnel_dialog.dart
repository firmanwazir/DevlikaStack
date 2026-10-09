import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/site_model.dart';
import '../services/tunnel_service.dart';
import '../services/config_service.dart';
import '../theme/app_theme.dart';

class TunnelDialog extends StatelessWidget {
  final SiteModel? site;
  final String? customDomain;
  final int? localPort;

  const TunnelDialog({
    super.key,
    this.site,
    this.customDomain,
    this.localPort,
  });

  String get targetDomain => site?.domain ?? customDomain ?? 'localhost';
  int get effectivePort => localPort ?? ConfigService.instance.httpPort;

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
          backgroundColor: AppTheme.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.borderDark),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderDark),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.cloud_sync_outlined,
                          color: AppTheme.accentIndigo,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Cloudflare Quick Tunnel',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Expose host lokal ke internet secara aman melalui Cloudflare Edge.',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 18),
                      splashRadius: 18,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Target Site Info Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.dns_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      const Text(
                        'Target Host: ',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
                      ),
                      Text(
                        targetDomain,
                        style: AppTheme.monoStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.borderDark),
                        ),
                        child: Text(
                          ':$effectivePort',
                          style: AppTheme.monoStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Content based on state
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
                      color: AppTheme.accentRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accentRed.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(Icons.error_outline, color: AppTheme.accentRed, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tunnel.lastError!,
                            style: AppTheme.monoStyle(
                              color: AppTheme.accentRed,
                              fontSize: 11.5,
                            ),
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
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentIndigo),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tunnel.downloadStatus,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: tunnel.downloadProgress > 0 ? tunnel.downloadProgress : null,
              backgroundColor: AppTheme.surfaceElevated,
              color: AppTheme.accentIndigo,
              minHeight: 4,
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
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Komponen cloudflared Diperlukan',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Fitur ini membutuhkan binary resmi Cloudflare Tunnel (~55 MB). Hanya perlu diunduh satu kali dan langsung siap digunakan tanpa akun.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 15),
              label: const Text('Unduh cloudflared Sekarang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
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
      padding: const EdgeInsets.all(22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        children: const [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentIndigo),
          ),
          SizedBox(height: 12),
          Text(
            'Menghubungkan ke Cloudflare Edge...',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Membuat rute HTTPS publik terenkripsi.',
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
        // Status Row
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentGreen,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'LIVE & SECURE (HTTPS)',
              style: TextStyle(
                color: AppTheme.accentGreen,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Public URL Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.accentGreen.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, size: 15, color: AppTheme.accentGreen),
              const SizedBox(width: 10),
              Expanded(
                child: SelectableText(
                  url,
                  style: AppTheme.monoStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 15, color: AppTheme.textSecondary),
                tooltip: 'Salin Tautan',
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Tautan berhasil disalin: $url'),
                      backgroundColor: AppTheme.cardDark,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: AppTheme.borderDark),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Info note
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.info_outline, size: 13, color: AppTheme.textMuted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tautan publik ini dilindungi sertifikat TLS resmi Cloudflare dan dapat dibuka oleh siapa saja tanpa peringatan keamanan.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Buka Browser'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: const BorderSide(color: AppTheme.borderDark),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => launchUrl(Uri.parse(url)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.stop_rounded, size: 15),
                label: const Text('Hentikan Tunnel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed.withOpacity(0.15),
                  foregroundColor: AppTheme.accentRed,
                  elevation: 0,
                  side: BorderSide(color: AppTheme.accentRed.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
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
          'Publikasikan Host Ini ke Internet',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cloudflare Quick Tunnel membuat URL HTTPS publik acak yang langsung terhubung ke port lokal ini tanpa memerlukan port forwarding atau IP publik statis.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.4),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.flash_on_rounded, size: 16),
            label: const Text('Mulai Quick Tunnel'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentIndigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              elevation: 0,
            ),
            onPressed: () {
              tunnel.startTunnel(domain: targetDomain, localPort: effectivePort);
            },
          ),
        ),
      ],
    );
  }
}
