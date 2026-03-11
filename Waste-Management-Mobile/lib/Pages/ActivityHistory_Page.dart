import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/recycling_log.dart';
import '../models/waste_classification.dart';
import '../services/api_client.dart';
import '../services/recycling_service.dart';
import '../services/waste_service.dart';

class ActivityHistoryPage extends StatefulWidget {
  const ActivityHistoryPage({super.key});

  @override
  State<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends State<ActivityHistoryPage>
    with SingleTickerProviderStateMixin {
  final RecyclingService _recyclingService = RecyclingService();
  final WasteService _wasteService = WasteService();
  final ScrollController _logScrollController = ScrollController();
  final ScrollController _scanScrollController = ScrollController();
  late TabController _tabController;

  // Recycling Logs state
  List<RecyclingLog> _logs = [];
  int _logPage = 1;
  bool _isLoadingLogs = true;
  bool _isLoadingMoreLogs = false;
  bool _hasMoreLogs = true;
  int _totalLogs = 0;

  // Scans (Classifications) state
  List<WasteClassification> _scans = [];
  int _scanPage = 1;
  bool _isLoadingScans = true;
  bool _isLoadingMoreScans = false;
  bool _hasMoreScans = true;
  int _totalScans = 0;

  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
    _loadScans();
    
    _logScrollController.addListener(() {
      if (_logScrollController.position.pixels >= _logScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMoreLogs && _hasMoreLogs) _loadMoreLogs();
      }
    });
    
    _scanScrollController.addListener(() {
      if (_scanScrollController.position.pixels >= _scanScrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMoreScans && _hasMoreScans) _loadMoreScans();
      }
    });
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    _scanScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Data Loading ─────────────────────────────────────────────────────────

  Future<void> _loadLogs() async {
    if (!mounted) return;
    setState(() { _isLoadingLogs = true; _error = null; });
    try {
      final response = await _recyclingService.getLogs(page: 1, limit: 15);
      if (!mounted) return;
      setState(() {
        _logs = response.logs;
        _logPage = 1;
        _totalLogs = response.pagination.total;
        _hasMoreLogs = response.pagination.page < response.pagination.totalPages;
        _isLoadingLogs = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _isLoadingLogs = false; });
    }
  }

  Future<void> _loadMoreLogs() async {
    if (_isLoadingMoreLogs || !_hasMoreLogs) return;
    setState(() => _isLoadingMoreLogs = true);
    try {
      final response = await _recyclingService.getLogs(page: _logPage + 1, limit: 15);
      if (!mounted) return;
      setState(() {
        _logs.addAll(response.logs);
        _logPage++;
        _hasMoreLogs = response.pagination.page < response.pagination.totalPages;
        _isLoadingMoreLogs = false;
      });
    } catch (e) {
      setState(() => _isLoadingMoreLogs = false);
    }
  }

  Future<void> _loadScans() async {
    if (!mounted) return;
    setState(() { _isLoadingScans = true; });
    try {
      final response = await _wasteService.getHistory(page: 1, limit: 15);
      if (!mounted) return;
      setState(() {
        _scans = response.classifications;
        _scanPage = 1;
        _totalScans = response.pagination.total;
        _hasMoreScans = response.pagination.page < response.pagination.totalPages;
        _isLoadingScans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoadingScans = false; });
    }
  }

  Future<void> _loadMoreScans() async {
    if (_isLoadingMoreScans || !_hasMoreScans) return;
    setState(() => _isLoadingMoreScans = true);
    try {
      final response = await _wasteService.getHistory(page: _scanPage + 1, limit: 15);
      if (!mounted) return;
      setState(() {
        _scans.addAll(response.classifications);
        _scanPage++;
        _hasMoreScans = response.pagination.page < response.pagination.totalPages;
        _isLoadingMoreScans = false;
      });
    } catch (e) {
      setState(() => _isLoadingMoreScans = false);
    }
  }

  // ── Deletion ─────────────────────────────────────────────────────────────

  Future<void> _deleteLog(RecyclingLog log) async {
    final confirmed = await _showDeleteDialog();
    if (confirmed != true) return;

    try {
      await _recyclingService.deleteLog(log.id);
      if (!mounted) return;
      setState(() {
        _logs.removeWhere((l) => l.id == log.id);
        _totalLogs--;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<void> _deleteScan(WasteClassification scan) async {
    final confirmed = await _showDeleteDialog();
    if (confirmed != true) return;

    try {
      await _wasteService.deleteClassification(scan.id);
      if (!mounted) return;
      setState(() {
        _scans.removeWhere((s) => s.id == scan.id);
        _totalScans--;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scan record deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  Future<bool?> _showDeleteDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete from history?'),
        content: const Text('Are you sure you want to remove this record? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A2E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Activity History',
          style: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Recycling'),
            Tab(text: 'Scans'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecyclingList(),
          _buildScansList(),
        ],
      ),
    );
  }

  Widget _buildRecyclingList() {
    if (_isLoadingLogs) return const Center(child: CircularProgressIndicator());
    if (_error != null && _logs.isEmpty) return _buildErrorState();
    if (_logs.isEmpty) return _buildEmptyState('No recycling activities yet');

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView.builder(
        controller: _logScrollController,
        padding: const EdgeInsets.all(20),
        itemCount: _logs.length + (_isLoadingMoreLogs ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _logs.length) return const _LoadingMoreIndicator();
          final log = _logs[index];
          return Dismissible(
            key: Key('log_${log.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async { await _deleteLog(log); return false; },
            background: _buildDeleteBackground(),
            child: _ActivityLogCard(log: log),
          );
        },
      ),
    );
  }

  Widget _buildScansList() {
    if (_isLoadingScans) return const Center(child: CircularProgressIndicator());
    if (_scans.isEmpty) return _buildEmptyState('No scan history yet');

    return RefreshIndicator(
      onRefresh: _loadScans,
      child: ListView.builder(
        controller: _scanScrollController,
        padding: const EdgeInsets.all(20),
        itemCount: _scans.length + (_isLoadingMoreScans ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _scans.length) return const _LoadingMoreIndicator();
          final scan = _scans[index];
          return Dismissible(
            key: Key('scan_${scan.id}'),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async { await _deleteScan(scan); return false; },
            background: _buildDeleteBackground(),
            child: _ScanLogCard(scan: scan),
          );
        },
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error ?? 'An error occurred'),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadLogs, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

// ── Cards ──────────────────────────────────────────────────────────────────

class _ActivityLogCard extends StatelessWidget {
  final RecyclingLog log;
  const _ActivityLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final color = _getWasteColor(log.wasteType);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(_getWasteIcon(log.wasteType), color: color),
        ),
        title: Text(log.wasteType.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${log.createdAt?.day}/${log.createdAt?.month}/${log.createdAt?.year}'),
        trailing: Text(
          '+${log.rewardPoints} pts',
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  IconData _getWasteIcon(String type) {
    switch (type.toLowerCase()) {
      case 'plastic': return Icons.water_drop;
      case 'paper': return Icons.description;
      case 'organic': return Icons.eco;
      case 'glass': return Icons.wine_bar;
      case 'metal': return Icons.build;
      default: return Icons.recycling;
    }
  }

  Color _getWasteColor(String type) {
    switch (type.toLowerCase()) {
      case 'plastic': return Colors.blue;
      case 'paper': return Colors.orange;
      case 'organic': return Colors.green;
      case 'glass': return Colors.teal;
      case 'metal': return Colors.blueGrey;
      default: return Colors.grey;
    }
  }
}

class _ScanLogCard extends StatelessWidget {
  final WasteClassification scan;
  const _ScanLogCard({required this.scan});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: scan.imageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ApiClient().getFileUrl(scan.imageUrl!),
                  width: 50, height: 50, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
              )
            : const Icon(Icons.qr_code_scanner),
        title: Text(scan.rawLabel!.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confidence: ${(scan.confidence * 100).toStringAsFixed(1)}%'),
            if (scan.createdAt != null)
              Text('${scan.createdAt!.day}/${scan.createdAt!.month}/${scan.createdAt!.year}'),
          ],
        ),
        trailing: scan.status == 'denied'
            ? const Icon(Icons.block, color: Colors.red, size: 20)
            : const Icon(Icons.check_circle, color: Colors.green, size: 20),
      ),
    );
  }
}
