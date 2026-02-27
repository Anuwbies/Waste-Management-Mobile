import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reusable error / status widgets used across all pages for consistent UX.
// ─────────────────────────────────────────────────────────────────────────────

/// Full-page (or overlay-friendly) error card.
///
/// Shows an icon hero, title, message, optional retry button, and optional
/// secondary action (e.g. "Go Back" / "Go Home").
class ErrorCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? detail;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const ErrorCard({
    super.key,
    this.icon = Icons.error_outline,
    this.iconColor = Colors.red,
    required this.title,
    required this.message,
    this.detail,
    this.retryLabel,
    this.onRetry,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Hero icon ────────────────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(height: 20),

            // ── Title ────────────────────────────────────────────────
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 12),

            // ── Message ──────────────────────────────────────────────
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),

            // ── Optional detail chip ─────────────────────────────────
            if (detail != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: iconColor.withOpacity(0.25)),
                ),
                child: Text(
                  detail!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),

            // ── Retry button ─────────────────────────────────────────
            if (onRetry != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    retryLabel ?? 'Retry',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // ── Secondary action ─────────────────────────────────────
            if (onSecondary != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel ?? 'Go Back'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Slim offline / warning banner displayed at the top of a page body.
class OfflineBanner extends StatelessWidget {
  final String message;
  final IconData icon;

  const OfflineBanner({
    super.key,
    this.message = 'You are offline',
    this.icon = Icons.wifi_off,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[800],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline warning banner (e.g. "Using cached / fallback data").
class WarningBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color? color;

  const WarningBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: c, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
