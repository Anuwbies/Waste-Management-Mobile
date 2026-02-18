import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/scan_session.dart';
import '../services/waste_service.dart';
import 'RewardDecision_Page.dart';

/// LLM Disposal Suggestion Page
/// Shows disposal instructions from the LLM backend
/// User can proceed to submit for rewards
class LlmSuggestionPage extends StatefulWidget {
  final ScanSession session;

  const LlmSuggestionPage({
    super.key,
    required this.session,
  });

  @override
  State<LlmSuggestionPage> createState() => _LlmSuggestionPageState();
}

class _LlmSuggestionPageState extends State<LlmSuggestionPage> {
  late ScanSession _session;
  final WasteService _wasteService = WasteService();
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final suggestion = await _wasteService.getDisposalSuggestion(
        _session.classification!.label,
        confidence: _session.classification!.confidence,
      );

      setState(() {
        _session = _session.copyWithSuggestion(suggestion);
        _isLoading = false;
      });
    } catch (e) {
      // Still allow proceeding with default suggestion
      final fallbackSuggestion = DisposalSuggestion.getDefault(
        _session.classification!.label,
      );
      setState(() {
        _session = _session.copyWithSuggestion(fallbackSuggestion);
        _isLoading = false;
        _errorMessage = 'Using default suggestions (LLM unavailable)';
      });
    }
  }

  DisposalSuggestion? get _suggestion => _session.suggestion;

  /// Whether the CNN confidence meets the reward threshold.
  bool get _meetsRewardThreshold =>
      (_session.classification?.confidence ?? 0) >=
      ApiConfig.cnnConfidenceThreshold;

  void _proceedToReward() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RewardDecisionPage(session: _session),
      ),
    );
  }

  void _goBack() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Disposal Instructions'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          SizedBox(height: 20),
          Text(
            'Getting disposal instructions...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning banner if using fallback
          if (_errorMessage != null) _buildWarningBanner(),

          // Low-confidence reward banner
          if (!_meetsRewardThreshold) _buildLowConfidenceBanner(),

          // Header with waste type
          _buildHeader(),
          const SizedBox(height: 20),

          // Bin type card
          if (_suggestion != null) _buildBinTypeCard(),
          const SizedBox(height: 16),

          // Disposal steps
          if (_suggestion != null) _buildStepsCard(),
          const SizedBox(height: 16),

          // Warnings
          if (_suggestion != null && _suggestion!.warnings.isNotEmpty)
            _buildWarningsCard(),
          if (_suggestion != null && _suggestion!.warnings.isNotEmpty)
            const SizedBox(height: 16),

          // Tips
          if (_suggestion != null && _suggestion!.tips.isNotEmpty)
            _buildTipsCard(),
          if (_suggestion != null && _suggestion!.tips.isNotEmpty)
            const SizedBox(height: 16),

          // Local rules
          if (_suggestion != null &&
              _suggestion!.localRules != null &&
              _suggestion!.localRules!.isNotEmpty)
            _buildLocalRulesCard(),

          const SizedBox(height: 24),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Image thumbnail
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _session.imageFile,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Classification info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _session.classification!.label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_session.classification!.confidence * 100).toStringAsFixed(1)}% confidence',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${_session.classification!.potentialPoints} pts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBinTypeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              _getBinColor().withOpacity(0.1),
              _getBinColor().withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            // Bin icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getBinColor().withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete,
                size: 32,
                color: _getBinColor(),
              ),
            ),
            const SizedBox(width: 16),

            // Bin info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Place in',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${_suggestion!.binType} Bin',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _getBinColor(),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward,
              color: _getBinColor().withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.format_list_numbered, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Disposal Steps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(_suggestion!.steps.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _suggestion!.steps[index],
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Important Warnings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._suggestion!.warnings.map((warning) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Helpful Tips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._suggestion!.tips.map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.star, color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalRulesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_on, color: Colors.purple),
                SizedBox(width: 8),
                Text(
                  'Local Rules',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _suggestion!.localRules!,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner shown when confidence is below the reward threshold.
  Widget _buildLowConfidenceBanner() {
    final pct = ((_session.classification?.confidence ?? 0) * 100)
        .toStringAsFixed(1);
    final threshPct =
        (ApiConfig.cnnConfidenceThreshold * 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.red.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confidence too low for rewards',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your classification confidence is $pct%, '
                  'but at least $threshPct% is required.\n'
                  'You can still view disposal instructions below, '
                  'but reward submission is disabled.',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final canSubmit = _suggestion != null && _meetsRewardThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary action - submit for reward (disabled when below threshold)
        ElevatedButton(
          onPressed: canSubmit ? _proceedToReward : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? Colors.green : Colors.grey[400],
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[500],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: canSubmit ? 2 : 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(canSubmit ? Icons.check_circle : Icons.block, size: 22),
              const SizedBox(width: 8),
              Text(
                canSubmit ? 'Submit for Rewards' : 'Rewards Unavailable',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // Hint text when disabled
        if (!_meetsRewardThreshold)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Retake the photo for a clearer image to qualify for rewards.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),

        const SizedBox(height: 12),

        // Retake photo (prominent when below threshold)
        if (!_meetsRewardThreshold)
          ElevatedButton(
            onPressed: () {
              // Pop back two pages (LlmSuggestion → CnnResult → Camera)
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
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
                  'Retake Photo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

        if (!_meetsRewardThreshold) const SizedBox(height: 12),

        // Secondary action - go back
        OutlinedButton(
          onPressed: _goBack,
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
              Icon(Icons.arrow_back),
              SizedBox(width: 8),
              Text(
                'Back to Classification',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getBinColor() {
    switch (_suggestion?.binType.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'brown':
        return Colors.brown;
      case 'yellow':
        return Colors.amber;
      case 'red':
        return Colors.red;
      case 'gray':
      case 'grey':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }
}
