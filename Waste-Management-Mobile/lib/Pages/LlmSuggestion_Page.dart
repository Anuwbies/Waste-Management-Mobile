import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/disposal_guide.dart';
import '../models/scan_session.dart';
import '../services/api_client.dart';
import '../services/waste_service.dart';
import '../services/recycling_service.dart';
import 'RewardDecision_Page.dart';

/// LLM Disposal Suggestion Page
///
/// Fetches a structured disposal guide from the backend (`POST /waste/suggestion`)
/// and displays it. Shows a "Submit for Rewards" button **only** when the CNN
/// confidence meets the reward threshold. The `/recycle` call is made exclusively
/// inside the button handler — never automatically.
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
  final RecyclingService _recyclingService = RecyclingService();

  // ── UI state ─────────────────────────────────────────────────────
  bool _isLoadingGuide = true;
  bool _isSubmitting = false;
  DisposalGuide? _guide;
  String? _errorMessage;

  // ── Derived helpers ──────────────────────────────────────────────
  CnnClassification? get _classification => _session.classification;

  bool get _meetsRewardThreshold =>
      (_classification?.confidence ?? 0) >= ApiConfig.cnnConfidenceThreshold;

  @override
  void initState() {
    super.initState();
    _session = widget.session;

    if (kDebugMode) {
      debugPrint('[LlmSuggestion] Session wasteType=${_classification?.label}, '
          'confidence=${_classification?.confidence}, '
          'threshold=${ApiConfig.cnnConfidenceThreshold}, '
          'eligible=$_meetsRewardThreshold');
    }

    _fetchDisposalGuide();
  }

  // ─── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchDisposalGuide() async {
    setState(() {
      _isLoadingGuide = true;
      _errorMessage = null;
    });

    try {
      final guide = await _wasteService.getDisposalGuide(
        wasteType: _classification!.label,
        confidence: _classification!.confidence,
        topK: _classification!.topK?.map((p) => p.label).toList(),
        rawLabel: _classification!.rawLabel,
      );

      if (!mounted) return;
      setState(() {
        _guide = guide;
        _isLoadingGuide = false;
      });

      // Also store a DisposalSuggestion on the session so downstream pages
      // (RewardDecision) can access it.
      _session = _session.copyWithSuggestion(
        DisposalSuggestion(
          binType: guide.bin,
          steps: guide.steps,
          warnings: guide.doNot,
          tips: guide.tips,
          isRecyclable: true,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingGuide = false;
        _errorMessage = _mapApiError(e);
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoadingGuide = false;
        _errorMessage =
            'Request timed out. Please check your connection and try again.';
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _isLoadingGuide = false;
        _errorMessage = 'No internet connection. Please check your network.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingGuide = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
      if (kDebugMode) debugPrint('[LlmSuggestion] Unexpected error: $e');
    }
  }

  /// Map [ApiException] to a user-friendly message.
  String _mapApiError(ApiException e) {
    switch (e.statusCode) {
      case 401:
        // Schedule navigation to login after frame builds
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
        return 'Session expired. Redirecting to login…';
      case 503:
        return 'Suggestion service is temporarily unavailable. Please try again later.';
      case 422:
        return 'Invalid request. Please go back and try again.';
      default:
        return 'Could not load disposal guide. Tap Retry to try again.';
    }
  }

  // ─── Reward submission ────────────────────────────────────────────────────

  /// Called ONLY when the user taps "Submit for Rewards".
  Future<void> _submitForRewards() async {
    if (_isSubmitting || !_meetsRewardThreshold) return;

    setState(() => _isSubmitting = true);

    try {
      // Ensure we have a suggestion on the session
      if (_session.suggestion == null && _guide != null) {
        _session = _session.copyWithSuggestion(
          DisposalSuggestion(
            binType: _guide!.bin,
            steps: _guide!.steps,
            warnings: _guide!.doNot,
            tips: _guide!.tips,
            isRecyclable: true,
          ),
        );
      }

      if (!mounted) return;

      // Navigate to RewardDecisionPage which handles the /recycle call
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RewardDecisionPage(session: _session),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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
      body: _isLoadingGuide
          ? _buildLoading()
          : _errorMessage != null && _guide == null
              ? _buildError()
              : _buildContent(),
    );
  }

  // ── Loading state ──────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          const SizedBox(height: 20),
          Text(
            'Getting disposal instructions…',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Powered by AI',
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  // ── Error state — shows fallback disposal template ──────────────────────

  /// Build a minimal disposal guide from local config when the LLM API fails.
  DisposalGuide _buildFallbackGuide() {
    final wasteType = _classification?.label ?? 'Waste';
    final bin = ApiConfig.wasteBinColors[wasteType.toLowerCase()] ?? 'General';
    return DisposalGuide(
      title: 'Basic Disposal Guide for $wasteType',
      bin: bin,
      steps: [
        'Ensure the item is clean and dry.',
        'Place in the $bin bin.',
        'Follow your local recycling guidelines for $wasteType.',
      ],
      doNot: [
        'Do not mix with hazardous waste.',
      ],
      tips: [
        'When in doubt, check your local waste authority\'s website.',
      ],
      safety: [],
    );
  }

  Widget _buildError() {
    // Generate a local fallback and render it with a warning banner,
    // so the user still gets useful info even when the API is down.
    final fallback = _buildFallbackGuide();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Warning: fallback content
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Guide Unavailable',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Showing basic template. Tap Retry for the full AI-powered guide.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Retry + Go Back row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _fetchDisposalGuide,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Header
          _buildHeader(),
          const SizedBox(height: 20),

          // Fallback guide title
          Text(
            fallback.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),

          // Bin card (reuse the existing builder after temporarily swapping _guide)
          _buildFallbackBinCard(fallback),
          const SizedBox(height: 16),

          // Steps
          _buildFallbackStepsCard(fallback),
          const SizedBox(height: 16),

          // Do Not
          if (fallback.doNot.isNotEmpty)
            _buildFallbackDoNotCard(fallback),
          if (fallback.doNot.isNotEmpty)
            const SizedBox(height: 16),

          // Tips
          if (fallback.tips.isNotEmpty)
            _buildFallbackTipsCard(fallback),
        ],
      ),
    );
  }

  // Lightweight card builders for the fallback guide (mirrors the real ones)
  Widget _buildFallbackBinCard(DisposalGuide guide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.delete_outline, color: Colors.green.shade700, size: 32),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Recommended Bin',
                  style: TextStyle(fontSize: 13, color: Colors.green.shade600)),
              Text(guide.bin,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackStepsCard(DisposalGuide guide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist, color: Colors.green),
              SizedBox(width: 8),
              Text('Disposal Steps', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...guide.steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14, height: 1.4))),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildFallbackDoNotCard(DisposalGuide guide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 8),
            const Text('Avoid', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          ...guide.doNot.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.close, size: 16, color: Colors.red.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 14, height: 1.4))),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildFallbackTipsCard(DisposalGuide guide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline, color: Colors.blue.shade400),
            const SizedBox(width: 8),
            const Text('Tips', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          ...guide.tips.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.eco, size: 16, color: Colors.blue.shade400),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 14, height: 1.4))),
                ]),
              )),
        ],
      ),
    );
  }

  // ── Success content ────────────────────────────────────────────────────────

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fallback warning banner
          if (_errorMessage != null) _buildWarningBanner(_errorMessage!),

          // Low-confidence gating banner
          if (!_meetsRewardThreshold) _buildLowConfidenceBanner(),

          // Header with waste type + thumbnail
          _buildHeader(),
          const SizedBox(height: 20),

          // Guide title
          if (_guide != null)
            Text(
              _guide!.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
          const SizedBox(height: 16),

          // Bin card
          if (_guide != null) _buildBinCard(),
          const SizedBox(height: 16),

          // Steps
          if (_guide != null && _guide!.steps.isNotEmpty) _buildStepsCard(),
          const SizedBox(height: 16),

          // Do Not
          if (_guide != null && _guide!.doNot.isNotEmpty) _buildDoNotCard(),
          if (_guide != null && _guide!.doNot.isNotEmpty)
            const SizedBox(height: 16),

          // Tips
          if (_guide != null && _guide!.tips.isNotEmpty) _buildTipsCard(),
          if (_guide != null && _guide!.tips.isNotEmpty)
            const SizedBox(height: 16),

          // Safety
          if (_guide != null && _guide!.safety.isNotEmpty) _buildSafetyCard(),
          if (_guide != null && _guide!.safety.isNotEmpty)
            const SizedBox(height: 16),

          const SizedBox(height: 24),

          // Action buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  // ── Banners ────────────────────────────────────────────────────────────────

  Widget _buildWarningBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.orange, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowConfidenceBanner() {
    final pct =
        ((_classification?.confidence ?? 0) * 100).toStringAsFixed(1);
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
                  'Not eligible for rewards (low confidence)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence $pct% is below the $threshPct% threshold.\n'
                  'You can still view disposal instructions, but reward '
                  'submission is disabled.',
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

  // ── Header ─────────────────────────────────────────────────────────────────

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
            child: Image.file(_session.imageFile, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 16),

        // Classification info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _meetsRewardThreshold
                    ? _classification!.label.toUpperCase()
                    : 'UNRECOGNIZED ITEM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _meetsRewardThreshold
                      ? const Color(0xFF333333)
                      : Colors.grey[600]!,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_classification!.confidence * 100).toStringAsFixed(1)}% confidence',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              if (_meetsRewardThreshold)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        'Potential ${_classification!.potentialPoints} pts',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.block, color: Colors.grey, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Rewards unavailable',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
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

  // ── Cards ──────────────────────────────────────────────────────────────────

  Widget _buildBinCard() {
    final binColor = _getBinColor(_guide!.bin);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              binColor.withOpacity(0.1),
              binColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: binColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete, size: 32, color: binColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Place in',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(
                    '${_guide!.bin} Bin',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: binColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: binColor.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsCard() {
    return _sectionCard(
      icon: Icons.format_list_numbered,
      iconColor: Colors.green,
      title: 'Disposal Steps',
      child: Column(
        children: List.generate(_guide!.steps.length, (i) {
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
                      '${i + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_guide!.steps[i],
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDoNotCard() {
    return _sectionCard(
      icon: Icons.warning_amber,
      iconColor: Colors.red,
      title: 'Do NOT',
      backgroundColor: Colors.red.shade50,
      child: Column(
        children: _guide!.doNot.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 14))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTipsCard() {
    return _sectionCard(
      icon: Icons.lightbulb_outline,
      iconColor: Colors.blue,
      title: 'Helpful Tips',
      backgroundColor: Colors.blue.shade50,
      child: Column(
        children: _guide!.tips.map((tip) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.star, color: Colors.blue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(tip, style: const TextStyle(fontSize: 14))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSafetyCard() {
    return _sectionCard(
      icon: Icons.health_and_safety,
      iconColor: Colors.orange,
      title: 'Safety Notes',
      backgroundColor: Colors.orange.shade50,
      child: Column(
        children: _guide!.safety.map((note) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(note, style: const TextStyle(fontSize: 14))),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Generic section card builder.
  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Color? backgroundColor,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ── Action buttons ─────────────────────────────────────────────────────────

  Widget _buildActionButtons() {
    final canSubmit = _guide != null && _meetsRewardThreshold && !_isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary: submit for rewards (disabled when below threshold)
        ElevatedButton(
          onPressed: canSubmit ? _submitForRewards : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canSubmit ? Colors.green : Colors.grey[400],
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey[300],
            disabledForegroundColor: Colors.grey[500],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: canSubmit ? 2 : 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(canSubmit ? Icons.check_circle : Icons.block,
                        size: 22),
                    const SizedBox(width: 8),
                    Text(
                      canSubmit
                          ? 'Submit for Rewards'
                          : 'Rewards Unavailable',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),

        // Hint when disabled
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
          ElevatedButton.icon(
            onPressed: () {
              // Pop back two pages (LlmSuggestion → CnnResult → Camera)
              Navigator.pop(context);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text('Retake Photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 2,
            ),
          ),

        if (!_meetsRewardThreshold) const SizedBox(height: 12),

        // Secondary: go back
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            side: BorderSide(color: Colors.grey[400]!),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back),
              SizedBox(width: 8),
              Text('Back to Classification',
                  style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _getBinColor(String bin) {
    switch (bin.toLowerCase()) {
      case 'blue':
        return Colors.blue;
      case 'green':
      case 'green/brown':
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
        // Check if the bin string contains a known colour word
        final lower = bin.toLowerCase();
        if (lower.contains('blue')) return Colors.blue;
        if (lower.contains('green')) return Colors.green;
        if (lower.contains('brown')) return Colors.brown;
        if (lower.contains('red')) return Colors.red;
        return Colors.green;
    }
  }
}
