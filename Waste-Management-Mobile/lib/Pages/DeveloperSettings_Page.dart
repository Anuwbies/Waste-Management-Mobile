import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/api_client.dart';

/// Hidden developer settings screen.
///
/// Allows changing the API base URL at runtime without rebuilding.
/// Only reachable in debug builds (gated at the call site).
class DeveloperSettingsPage extends StatefulWidget {
  const DeveloperSettingsPage({super.key});

  @override
  State<DeveloperSettingsPage> createState() => _DeveloperSettingsPageState();
}

class _DeveloperSettingsPageState extends State<DeveloperSettingsPage> {
  late TextEditingController _urlController;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;
  bool _hasChanges = false;

  // Common presets for quick switching
  static const _presets = [
    _Preset('Android Emulator', 'http://10.0.2.2:5000'),
    _Preset('iOS Simulator', 'http://localhost:5000'),
    _Preset('LAN (192.168.1.x)', 'http://192.168.1.'),
  ];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ApiConfig.baseUrl);
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    setState(() {
      _hasChanges = _urlController.text.trim() != ApiConfig.baseUrl;
      _testResult = null;
    });
  }

  /// Test connectivity to the given URL by hitting the health endpoint.
  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      // Temporarily point ApiConfig to the new URL for the test
      final originalUrl = ApiConfig.baseUrl;
      await ApiConfig.setBaseUrl(url);

      try {
        // Use a more general health check instead of blockchain specific
        final response = await ApiClient().get('/user/me'); 
        // /user/me might fail with 401 if not logged in, but connectivity is confirmed
        setState(() {
          _testSuccess = true;
          _testResult = 'Server reached! (${response.toString().length} bytes)';
        });
      } catch (e) {
        // Revert if test fails — user hasn't confirmed save yet
        await ApiConfig.setBaseUrl(originalUrl);
        setState(() {
          _testSuccess = false;
          _testResult = 'Failed: ${e is ApiException ? e.userMessage : e}';
        });
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  /// Save the URL to SharedPreferences (persists across restarts).
  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    await ApiConfig.setBaseUrl(url);
    if (mounted) {
      setState(() => _hasChanges = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API URL updated to $url'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Reset to the dotenv / default value.
  Future<void> _reset() async {
    await ApiConfig.resetBaseUrl();
    if (mounted) {
      _urlController.text = ApiConfig.baseUrl;
      setState(() {
        _hasChanges = false;
        _testResult = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reset to default (.env) value'),
          backgroundColor: Colors.blueGrey,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Developer Settings'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Warning banner ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Debug only — changes here affect API connections immediately.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Current URL display ──────────────────────────────────────
          Text('Current Base URL',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.link, size: 18, color: Colors.grey[500]),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ApiConfig.baseUrl,
                    style: const TextStyle(
                        fontSize: 14, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── URL input ────────────────────────────────────────────────
          Text('New Base URL',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 6),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              hintText: 'http://10.0.2.2:5000',
              prefixIcon: const Icon(Icons.dns_outlined),
              suffixIcon: _urlController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => _urlController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
          ),
          const SizedBox(height: 16),

          // ── Quick presets ────────────────────────────────────────────
          Text('Quick Presets',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final isActive = ApiConfig.baseUrl == p.url ||
                  _urlController.text.trim() == p.url;
              return ActionChip(
                avatar: Icon(
                  isActive ? Icons.check_circle : Icons.computer,
                  size: 18,
                  color: isActive ? Colors.green : Colors.grey[600],
                ),
                label: Text(p.label),
                backgroundColor: isActive ? Colors.green.shade50 : null,
                onPressed: () {
                  _urlController.text = p.url;
                  // Place cursor at end (useful for LAN preset with partial IP)
                  _urlController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _urlController.text.length),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Action buttons ───────────────────────────────────────────
          Row(
            children: [
              // Test
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_find, size: 18),
                  label: Text(_isTesting ? 'Testing…' : 'Test'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _hasChanges ? _save : null,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reset
          Center(
            child: TextButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Reset to Default'),
            ),
          ),

          // ── Test result ──────────────────────────────────────────────
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                    _testSuccess ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _testSuccess
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _testSuccess ? Icons.check_circle : Icons.error_outline,
                    color: _testSuccess ? Colors.green : Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _testSuccess
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),

          // ── Info section ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text('How it Works',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700)),
                  ],
                ),
                const SizedBox(height: 10),
                _infoLine('1.', 'dotenv loads assets/env/.env.<ENV> at startup'),
                _infoLine('2.', 'SharedPreferences override wins if set here'),
                _infoLine('3.', '"Reset" clears the override → falls back to dotenv'),
                _infoLine('4.', 'Switch at build time: --dart-define=ENV=prod'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(num,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                    fontSize: 13)),
          ),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
          ),
        ],
      ),
    );
  }
}

class _Preset {
  final String label;
  final String url;
  const _Preset(this.label, this.url);
}
