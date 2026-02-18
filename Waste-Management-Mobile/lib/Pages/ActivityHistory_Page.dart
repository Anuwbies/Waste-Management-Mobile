import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/recycling_log.dart';
import '../services/api_client.dart';
import '../services/recycling_service.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage> {
  final RecyclingService _recyclingService = RecyclingService();
  final ScrollController _scrollController = ScrollController();

  List<RecyclingLog> _logs = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalFromServer = 0; // total count from pagination metadata
  String? _error;

  // Filter state — server-side filtering via ?wasteType= query param
  String? _selectedWasteType;
  static const List<String> _wasteTypes = [
    'All',
    'Plastic',
    'Paper',
    'Metal',
    'Glass',
    'Organic',
    'E-Waste',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Primary fetch — resets list, fetches page 1.
  /// Uses the same [RecyclingService.getLogs] as Home_Page.dart.
  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _recyclingService.getLogs(
        page: 1,
        limit: 20,
        wasteType: _selectedWasteType, // server-side filter (null = all)
      );

      if (!mounted) return;
      setState(() {
        _logs = response.logs;
        _currentPage = 1;
        _totalFromServer = response.pagination.total;
        _hasMore =
            response.pagination.page < response.pagination.totalPages;
        _isLoading = false;
      });

      if (kDebugMode) {
        print('[ActivityHistory] loaded ${response.logs.length} logs '
            '(total: ${response.pagination.total}, '
            'filter: ${_selectedWasteType ?? "all"})');
      }
    } on ApiException catch (e) {
      if (kDebugMode) {
        print('[ActivityHistory] ApiException: '
            'status=${e.statusCode}, msg=${e.message}');
      }
      if (!mounted) return;
      setState(() {
        _error = e.statusCode == 401
            ? 'Session expired — please log in again'
            : 'Failed to load activity history';
        _isLoading = false;
      });
      _showErrorSnackBar(e.message);
    } catch (e) {
      if (kDebugMode) print('[ActivityHistory] unexpected error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load activity history';
        _isLoading = false;
      });
      _showErrorSnackBar('$e');
    }
  }

  /// Infinite-scroll — appends next page to existing list.
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final response = await _recyclingService.getLogs(
        page: _currentPage + 1,
        limit: 20,
        wasteType: _selectedWasteType,
      );

      if (!mounted) return;
      setState(() {
        _logs.addAll(response.logs);
        _currentPage = response.pagination.page;
        _totalFromServer = response.pagination.total;
        _hasMore =
            response.pagination.page < response.pagination.totalPages;
        _isLoadingMore = false;
      });

      if (kDebugMode) {
        print('[ActivityHistory] loadMore => page $_currentPage, '
            '+${response.logs.length} items, total in list: ${_logs.length}');
      }
    } catch (e) {
      if (kDebugMode) print('[ActivityHistory] loadMore error: $e');
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  /// Changing filter chip triggers a fresh server fetch.
  void _onFilterChanged(String type) {
    final newFilter = type == 'All' ? null : type;
    if (newFilter == _selectedWasteType) return;
    setState(() => _selectedWasteType = newFilter);
    _loadLogs(); // re-fetch from server with new wasteType param
  }

  // ── Computed stats ──────────────────────────────────────────────────────
  int get _totalItems => _totalFromServer;

  int get _totalPoints {
    int pts = 0;
    for (final log in _logs) {
      pts += log.rewardPoints;
    }
    return pts;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  void _showErrorSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Retry', onPressed: _loadLogs),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Activity History',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: () async => _loadLogs(),
                  child: Column(
                    children: [
                      // Summary Card
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _SummaryCard(
                          totalItems: _totalItems,
                          totalPoints: _totalPoints,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filter chips
                      SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _wasteTypes.length,
                          itemBuilder: (context, index) {
                            final type = _wasteTypes[index];
                            final isSelected =
                                (_selectedWasteType == null &&
                                        type == 'All') ||
                                    _selectedWasteType == type;

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                label: Text(type),
                                onSelected: (_) => _onFilterChanged(type),
                                selectedColor:
                                    Colors.blue.withValues(alpha: 0.2),
                                checkmarkColor: Colors.blue,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey.shade700,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Logs list
                      Expanded(
                        child: _logs.isEmpty
                            ? _buildEmptyState()
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                itemCount:
                                    _logs.length + (_isLoadingMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == _logs.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                          child:
                                              CircularProgressIndicator()),
                                    );
                                  }
                                  return _ActivityLogCard(
                                    log: _logs[index],
                                    isFirst: index == 0,
                                    isLast:
                                        index == _logs.length - 1,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadLogs,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _selectedWasteType != null
                ? 'No $_selectedWasteType items found'
                : 'No recycling activity yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start scanning to earn rewards!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SUMMARY CARD
// ============================================================================

class _SummaryCard extends StatelessWidget {
  final int totalItems;
  final int totalPoints;

  const _SummaryCard({
    required this.totalItems,
    required this.totalPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.recycling, color: Colors.green, size: 28),
                const SizedBox(height: 8),
                Text(
                  '$totalItems',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  'Items Recycled',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: Colors.grey.shade200,
          ),
          Expanded(
            child: Column(
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 28),
                const SizedBox(height: 8),
                Text(
                  '$totalPoints',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                Text(
                  'Points Earned',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTIVITY LOG CARD
// ============================================================================

class _ActivityLogCard extends StatelessWidget {
  final RecyclingLog log;
  final bool isFirst;
  final bool isLast;

  const _ActivityLogCard({
    required this.log,
    this.isFirst = false,
    this.isLast = false,
  });

  IconData _getWasteIcon(String wasteType) {
    switch (wasteType.toLowerCase()) {
      case 'plastic':
        return Icons.water_drop_outlined;
      case 'paper':
        return Icons.description_outlined;
      case 'metal':
        return Icons.hardware_outlined;
      case 'glass':
        return Icons.wine_bar_outlined;
      case 'organic':
        return Icons.eco_outlined;
      case 'e-waste':
        return Icons.electrical_services_outlined;
      case 'battery':
        return Icons.battery_charging_full_outlined;
      default:
        return Icons.delete_outline;
    }
  }

  Color _getWasteColor(String wasteType) {
    switch (wasteType.toLowerCase()) {
      case 'plastic':
        return Colors.blue;
      case 'paper':
        return Colors.amber.shade700;
      case 'metal':
        return Colors.grey.shade700;
      case 'glass':
        return Colors.teal;
      case 'organic':
        return Colors.green;
      case 'e-waste':
        return Colors.red;
      case 'battery':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown date';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }

  // ── Status badge helpers ─────────────────────────────────────────────
  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      case 'duplicate':
        return Colors.grey;
      default:
        return Colors.green; // treat no-status as confirmed
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      case 'duplicate':
        return 'Duplicate';
      default:
        return 'Approved';
    }
  }

  @override
  Widget build(BuildContext context) {
    final wasteType = log.wasteType;
    final icon = _getWasteIcon(wasteType);
    final color = _getWasteColor(wasteType);

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 20 : 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          if (!isFirst)
            Divider(height: 1, color: Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _capitalizeFirst(wasteType),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(log.status)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _statusLabel(log.status),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _statusColor(log.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(log.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          if (log.quantity > 1) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'x${log.quantity}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Points
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '+${log.rewardPoints}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Transaction hash if available
          if (log.txHash != null && log.txHash!.length >= 16) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.link, size: 14, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text(
                    'On-chain: ${log.txHash!.substring(0, 10)}...${log.txHash!.substring(log.txHash!.length - 6)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade400,
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
}
