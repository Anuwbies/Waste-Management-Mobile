import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/api_config.dart';
import '../models/scan_session.dart';
import '../services/api_client.dart';
import '../services/connectivity_service.dart';
import '../services/recycling_service.dart';

// ---------------------------------------------------------------------------
// Structured error model – replaces the raw string _errorMessage
// ---------------------------------------------------------------------------

/// Categories of submission errors shown to the user.
enum _ErrorKind {
  imageTooLarge,
  networkTimeout,
  sessionExpired,
  duplicate,
  serverError,
  noInternet,
  unknown,
}

/// All the data needed to render a user-friendly error screen.
class _SubmissionError {
  final _ErrorKind kind;

  /// Short title displayed in large text (e.g. "Image Too Large").
  final String title;

  /// Longer description that tells the user what to do.
  final String description;

  /// Optional extra info line (e.g. "Your image: 14.2 MB — limit: 10 MB").
  final String? detail;

  /// Label for the primary action button.
  final String primaryAction;

  /// Icon shown in the error hero.
  final IconData icon;

  /// Colour theme for icon / title.
  final Color color;

  const _SubmissionError({
    required this.kind,
    required this.title,
    required this.description,
    this.detail,
    this.primaryAction = 'Retake Photo',
    this.icon = Icons.error_outline,
    this.color = Colors.red,
  });
}

/// Reward Decision Page
/// Shows the result of the recycling submission:
/// - APPROVED: Points awarded, blockchain transaction
/// - DENIED: Reason for denial (e.g., low confidence)
/// - PENDING: Awaiting manual review
class RewardDecisionPage extends StatefulWidget {
  final ScanSession session;

  const RewardDecisionPage({
    super.key,
    required this.session,
  });

  @override
  State<RewardDecisionPage> createState() => _RewardDecisionPageState();
}

class _RewardDecisionPageState extends State<RewardDecisionPage>
    with SingleTickerProviderStateMixin {
  late ScanSession _session;
  final RecyclingService _recyclingService = RecyclingService();
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isSubmitting = true;

  /// Structured error — null when there is no error.
  _SubmissionError? _error;

  /// Idempotency key — stays the same across retries for the same session
  late final String _idempotencyKey;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _idempotencyKey =
        '${DateTime.now().millisecondsSinceEpoch}_${_session.classification!.label}';

    // Setup success animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );

    _submitForReward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Error mapping
  // -----------------------------------------------------------------------

  /// Convert any caught exception into a user-friendly [_SubmissionError].
  _SubmissionError _mapError(Object error) {
    // --- ApiException (most backend errors) ---
    if (error is ApiException) {
      final code = error.statusCode;
      final msg = error.message.toLowerCase();

      // 413 – payload / image too large
      if (code == 413 || msg.contains('entity too large') || msg.contains('too large')) {
        return _SubmissionError(
          kind: _ErrorKind.imageTooLarge,
          title: 'Image Too Large',
          description:
              'The selected image exceeds the maximum allowed size.\n'
              'Please choose a smaller image or retake the photo.',
          detail: _imageSizeDetail(),
          primaryAction: 'Retake Photo',
          icon: Icons.photo_size_select_large,
          color: Colors.orange,
        );
      }

      // 401 – session expired
      if (code == 401) {
        return const _SubmissionError(
          kind: _ErrorKind.sessionExpired,
          title: 'Session Expired',
          description:
              'Your login session has expired.\nPlease log in again to continue.',
          primaryAction: 'Go to Login',
          icon: Icons.lock_outline,
          color: Color(0xFFEF6C00),
        );
      }

      // 409 – duplicate
      if (code == 409) {
        return const _SubmissionError(
          kind: _ErrorKind.duplicate,
          title: 'Already Submitted',
          description:
              'This item was already submitted for a reward.\nScan a new item instead.',
          primaryAction: 'Scan New Item',
          icon: Icons.content_copy,
          color: Colors.blueGrey,
        );
      }

      // 5xx – server error
      if (code != null && code >= 500) {
        return const _SubmissionError(
          kind: _ErrorKind.serverError,
          title: 'Server Error',
          description:
              'Our servers are having trouble right now.\n'
              'Please try again in a few moments.\n\n'
              'If your submission went through, it will appear in Activity History.',
          primaryAction: 'Try Again',
          icon: Icons.cloud_off,
          color: Colors.red,
        );
      }

      // No internet (ApiClient wraps SocketException with this message)
      if (msg.contains('no internet')) {
        return const _SubmissionError(
          kind: _ErrorKind.noInternet,
          title: 'No Internet',
          description:
              "It looks like you're offline.\nCheck your Wi-Fi or mobile data and try again.",
          primaryAction: 'Try Again',
          icon: Icons.wifi_off,
          color: Colors.blueGrey,
        );
      }
    }

    // --- Timeout ---
    if (error is TimeoutException || error is SocketException) {
      return const _SubmissionError(
        kind: _ErrorKind.networkTimeout,
        title: 'Connection Problem',
        description:
            'The request timed out or the network is unreachable.\n'
            'Please check your connection and try again.\n\n'
            'If your submission went through, check Activity History.',
        primaryAction: 'Try Again',
        icon: Icons.signal_wifi_connected_no_internet_4,
        color: Colors.orange,
      );
    }

    // --- Fallback ---
    return const _SubmissionError(
      kind: _ErrorKind.unknown,
      title: 'Something Went Wrong',
      description:
          'An unexpected error occurred.\nPlease try again or retake your photo.',
      primaryAction: 'Try Again',
      icon: Icons.warning_amber_rounded,
      color: Colors.red,
    );
  }

  /// Build an optional detail string showing actual vs allowed image size.
  String? _imageSizeDetail() {
    try {
      final bytes = _session.imageFile.lengthSync();
      final actualMB = (bytes / (1024 * 1024)).toStringAsFixed(1);
      final limitMB =
          (ApiConfig.maxUploadSize / (1024 * 1024)).toStringAsFixed(0);
      return 'Your image: $actualMB MB  •  Maximum allowed: $limitMB MB';
    } catch (_) {
      final limitMB =
          (ApiConfig.maxUploadSize / (1024 * 1024)).toStringAsFixed(0);
      return 'Maximum allowed size: $limitMB MB';
    }
  }

  // -----------------------------------------------------------------------
  // Submission
  // -----------------------------------------------------------------------

  Future<void> _submitForReward() async {
    // ── Client-side confidence guard (defense in depth) ──────────────
    final confidence = _session.classification?.confidence ?? 0;
    if (confidence < ApiConfig.cnnConfidenceThreshold) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _session = _session.copyWithDecision(
          RewardDecision.denied(
            'Confidence too low (${(confidence * 100).toStringAsFixed(1)}%). '
            'At least ${(ApiConfig.cnnConfidenceThreshold * 100).toStringAsFixed(0)}% is required.',
          ),
        );
      });
      _animationController.forward();
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _error = null;
      });

      // Connectivity pre-check — fail fast if offline
      if (!await _connectivity.isConnected) {
        if (kDebugMode) debugPrint('[RewardDecision] Offline — skipping submit');
        throw const SocketException('No internet connection');
      }

      final decision = await _recyclingService.submitRecyclingEvent(
        imageFile: _session.imageFile,
        classification: _session.classification!,
        suggestion: _session.suggestion!,
        idempotencyKey: _idempotencyKey,
      );

      if (!mounted) return;
      setState(() {
        _session = _session.copyWithDecision(decision);
        _isSubmitting = false;
      });

      // Trigger success animation
      _animationController.forward();

      // Haptic feedback based on result
      if (decision.status == RewardStatus.approved) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = _mapError(e);
      });
    }
  }

  RewardDecision? get _decision => _session.decision;

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _scanAgain() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _retry() {
    _submitForReward();
  }

  /// Primary error-button handler — action depends on error kind.
  void _onErrorPrimaryAction() {
    switch (_error?.kind) {
      case _ErrorKind.imageTooLarge:
      case _ErrorKind.duplicate:
        _scanAgain();
        break;
      case _ErrorKind.sessionExpired:
        _goHome(); // home screen redirects to login
        break;
      default:
        _retry();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: SafeArea(
        child: _isSubmitting
            ? _buildSubmittingState()
            : _error != null
                ? _buildErrorState()
                : _buildResultState(),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (_isSubmitting || _error != null) {
      return const Color(0xFFF5F5F5);
    }
    switch (_decision?.status) {
      case RewardStatus.approved:
        return const Color(0xFFE8F5E9); // Light green
      case RewardStatus.denied:
        return const Color(0xFFFFEBEE); // Light red
      case RewardStatus.pending:
        return const Color(0xFFFFF3E0); // Light orange
      default:
        return const Color(0xFFF5F5F5);
    }
  }

  Widget _buildSubmittingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1500),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value * 2 * 3.14159,
                child: child,
              );
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sync,
                color: Colors.green,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Submitting for Rewards...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Recording on blockchain',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              backgroundColor: Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final err = _error!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 24),

          // ── Hero icon ──────────────────────────────────────────────
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: err.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(err.icon, color: err.color, size: 52),
          ),
          const SizedBox(height: 28),

          // ── Title ──────────────────────────────────────────────────
          Text(
            err.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: err.color,
            ),
          ),
          const SizedBox(height: 14),

          // ── Description ────────────────────────────────────────────
          Text(
            err.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.grey[700],
            ),
          ),

          // ── Optional detail chip (e.g. image size) ─────────────────
          if (err.detail != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: err.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: err.color.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 18, color: err.color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      err.detail!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: err.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 36),

          // ── Primary action button ──────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _onErrorPrimaryAction,
              icon: Icon(_primaryActionIcon(err.kind)),
              label: Text(
                err.primaryAction,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: err.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Secondary: Go Home ─────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _goHome,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: Colors.grey[400]!),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home, size: 20),
                  SizedBox(width: 8),
                  Text('Go Home', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pick an icon for the primary error-action button.
  IconData _primaryActionIcon(_ErrorKind kind) {
    switch (kind) {
      case _ErrorKind.imageTooLarge:
        return Icons.camera_alt;
      case _ErrorKind.duplicate:
        return Icons.qr_code_scanner;
      case _ErrorKind.sessionExpired:
        return Icons.login;
      case _ErrorKind.networkTimeout:
      case _ErrorKind.noInternet:
      case _ErrorKind.serverError:
      case _ErrorKind.unknown:
        return Icons.refresh;
    }
  }

  Widget _buildResultState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Animated result icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: _buildResultIcon(),
          ),
          const SizedBox(height: 24),

          // Status text
          Text(
            _getStatusTitle(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getStatusSubtitle(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),

          const SizedBox(height: 32),

          // Points card (if approved)
          if (_decision?.status == RewardStatus.approved) _buildPointsCard(),

          // Details card
          _buildDetailsCard(),

          const SizedBox(height: 32),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildResultIcon() {
    IconData icon;
    Color color;
    Color bgColor;

    switch (_decision?.status) {
      case RewardStatus.approved:
        icon = Icons.check_circle;
        color = Colors.green;
        bgColor = Colors.green.withOpacity(0.2);
        break;
      case RewardStatus.denied:
        icon = Icons.cancel;
        color = Colors.red;
        bgColor = Colors.red.withOpacity(0.2);
        break;
      case RewardStatus.pending:
        icon = Icons.hourglass_top;
        color = Colors.orange;
        bgColor = Colors.orange.withOpacity(0.2);
        break;
      default:
        icon = Icons.help_outline;
        color = Colors.grey;
        bgColor = Colors.grey.withOpacity(0.2);
    }

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 60),
    );
  }

  String _getStatusTitle() {
    switch (_decision?.status) {
      case RewardStatus.approved:
        return 'APPROVED!';
      case RewardStatus.denied:
        return 'DENIED';
      case RewardStatus.pending:
        return 'PENDING';
      default:
        return 'UNKNOWN';
    }
  }

  String _getStatusSubtitle() {
    switch (_decision?.status) {
      case RewardStatus.approved:
        return 'Your recycling has been recorded on the blockchain!';
      case RewardStatus.denied:
        return _decision?.reason ?? 'Your submission did not qualify for rewards.';
      case RewardStatus.pending:
        return 'Your submission is under review. Check back later!';
      default:
        return '';
    }
  }

  Color _getStatusColor() {
    switch (_decision?.status) {
      case RewardStatus.approved:
        return Colors.green;
      case RewardStatus.denied:
        return Colors.red;
      case RewardStatus.pending:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildPointsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.stars,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            '+${_decision?.points ?? 0}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'POINTS EARNED',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 16),

            // Waste type
            _buildDetailRow(
              'Waste Type',
              _session.classification!.label.toUpperCase(),
              Icons.category,
            ),

            // Confidence
            _buildDetailRow(
              'Confidence',
              '${(_session.classification!.confidence * 100).toStringAsFixed(1)}%',
              Icons.analytics,
            ),

            // Bin type
            _buildDetailRow(
              'Bin Type',
              _session.suggestion!.binType,
              Icons.delete_outline,
            ),

            // Transaction hash (if available)
            if (_decision?.txHash != null &&
                _decision!.txHash!.isNotEmpty)
              _buildDetailRow(
                'Transaction',
                '${_decision!.txHash!.substring(0, 10)}...',
                Icons.receipt_long,
                onTap: () => _copyToClipboard(_decision!.txHash!),
              ),

            // Event ID (if available)
            if (_decision?.eventId != null && _decision!.eventId!.isNotEmpty)
              _buildDetailRow(
                'Event ID',
                _decision!.eventId!.length > 16
                    ? '${_decision!.eventId!.substring(0, 16)}...'
                    : _decision!.eventId!,
                Icons.tag,
              ),

            // Reason (if denied)
            if (_decision?.status == RewardStatus.denied &&
                _decision?.reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _decision!.reason!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: Colors.grey[500], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.copy, size: 14, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isDenied = _decision?.status == RewardStatus.denied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary – Retake Photo (for denied) or Scan Another (for approved/pending)
        ElevatedButton(
          onPressed: _scanAgain,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDenied ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.camera_alt),
              const SizedBox(width: 8),
              Text(
                isDenied ? 'Retake Photo' : 'Scan Another Item',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Secondary - go home
        OutlinedButton(
          onPressed: _goHome,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Colors.grey[400]!),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home),
              SizedBox(width: 8),
              Text(
                'Go to Home',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
