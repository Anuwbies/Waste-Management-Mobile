import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/scan_session.dart';
import '../services/recycling_service.dart';

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
  bool _isSubmitting = true;
  String? _errorMessage;

  /// Idempotency key — stays the same across retries for the same session
  late final String _idempotencyKey;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _idempotencyKey = '${DateTime.now().millisecondsSinceEpoch}_${_session.classification!.label}';

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

  Future<void> _submitForReward() async {
    try {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      final decision = await _recyclingService.submitRecyclingEvent(
        imageFile: _session.imageFile,
        classification: _session.classification!,
        suggestion: _session.suggestion!,
        idempotencyKey: _idempotencyKey,
      );

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
      setState(() {
        _isSubmitting = false;
        _errorMessage = e.toString();
      });
    }
  }

  RewardDecision? get _decision => _session.decision;

  void _goHome() {
    // Pop all and go to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _scanAgain() {
    // Pop all except home then navigate to camera
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _retry() {
    _submitForReward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBackgroundColor(),
      body: SafeArea(
        child: _isSubmitting
            ? _buildSubmittingState()
            : _errorMessage != null
                ? _buildErrorState()
                : _buildResultState(),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (_isSubmitting || _errorMessage != null) {
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 50,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Submission Failed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _retry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _goHome,
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary - scan again
        ElevatedButton(
          onPressed: _scanAgain,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.camera_alt),
              SizedBox(width: 8),
              Text(
                'Scan Another Item',
                style: TextStyle(
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
