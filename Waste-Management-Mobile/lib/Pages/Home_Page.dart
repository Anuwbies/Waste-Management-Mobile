import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/auth_response.dart';
import '../models/pagination.dart';
import '../models/recycling_log.dart';
import '../models/reward_models.dart';
import '../services/auth_service.dart';
import '../services/health_service.dart';
import '../services/recycling_service.dart';
import '../services/rewards_service.dart';
import 'ActivityHistory_Page.dart';
import 'Scan_Page.dart';
import 'Rewards_Page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  final RewardsService _rewardsService = RewardsService();
  final RecyclingService _recyclingService = RecyclingService();
  final HealthService _healthService = HealthService();

  // Dashboard data
  late Future<_DashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboardData();
  }

  Future<_DashboardData> _loadDashboardData() async {
    // Load all data in parallel
    final results = await Future.wait([
      _rewardsService.getBalance().catchError((_) => RewardBalance()),
      _recyclingService.getLogs(limit: 5).catchError(
        (_) => RecyclingLogsResponse(
          logs: [],
          pagination: Pagination(page: 1, limit: 5, total: 0, totalPages: 0),
        ),
      ),
      _healthService.getBlockchainHealth().catchError(
        (_) => BlockchainHealth(error: 'Could not reach backend'),
      ),
    ]);

    return _DashboardData(
      user: _authService.currentUser,
      balance: results[0] as RewardBalance,
      recentLogs: (results[1] as RecyclingLogsResponse).logs,
      blockchainHealth: results[2] as BlockchainHealth,
    );
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = _loadDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: FutureBuilder<_DashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }

            if (snapshot.hasError) {
              return _ErrorState(
                message: 'Failed to load dashboard',
                onRetry: _refreshDashboard,
              );
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => _refreshDashboard(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),

                      // Header with greeting
                      _HeaderSection(user: data.user),
                      const SizedBox(height: 24),

                      // Balance card
                      _BalanceCard(
                        balance: data.balance,
                        onViewWallet: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RewardsPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // Quick Actions
                      _QuickActionsSection(
                        onScan: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanPage()),
                        ),
                        onRewards: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RewardsPage()),
                        ),
                        onHistory: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ActivityHistoryPage()),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Recent Activity
                      _RecentActivitySection(
                        logs: data.recentLogs,
                        onSeeAll: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ActivityHistoryPage(),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // Rewards Guide
                      const _RewardsGuideSection(),
                      const SizedBox(height: 28),

                      // Blockchain Health (dev debug)
                      _BlockchainHealthSection(health: data.blockchainHealth),
                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// DATA MODEL
// ============================================================================

class _DashboardData {
  final UserData? user;
  final RewardBalance balance;
  final List<RecyclingLog> recentLogs;
  final BlockchainHealth blockchainHealth;

  _DashboardData({
    this.user,
    required this.balance,
    required this.recentLogs,
    required this.blockchainHealth,
  });
}

// ============================================================================
// LOADING & ERROR STATES
// ============================================================================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading dashboard...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HEADER SECTION
// ============================================================================

class _HeaderSection extends StatelessWidget {
  final UserData? user;

  const _HeaderSection({this.user});

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'there';
    final firstName = name.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $firstName! 👋',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Keep recycling for more rewards',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// BALANCE CARD
// ============================================================================

class _BalanceCard extends StatelessWidget {
  final RewardBalance balance;
  final VoidCallback onViewWallet;

  const _BalanceCard({required this.balance, required this.onViewWallet});

  String _shortenAddress(String? address) {
    if (address == null || address.length < 12) return 'Not connected';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  void _copyAddress(BuildContext context) {
    if (balance.walletAddress != null) {
      Clipboard.setData(ClipboardData(text: balance.walletAddress!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet address copied'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Balance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _shortenAddress(balance.walletAddress),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      if (balance.walletAddress != null) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _copyAddress(context),
                          child: Icon(
                            Icons.copy,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main points balance
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${balance.balance}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'points',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),

            // On-chain verification badge
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  balance.source == 'chain'
                      ? Icons.verified_outlined
                      : Icons.cloud_off_outlined,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  balance.source == 'chain'
                      ? 'Verified on-chain'
                      : 'Off-chain (cached)',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // View Wallet Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onViewWallet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF4F46E5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_outlined, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'View Rewards & Wallet',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
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
}

// ============================================================================
// QUICK ACTIONS
// ============================================================================

class _QuickActionsSection extends StatelessWidget {
  final VoidCallback onScan;
  final VoidCallback onRewards;
  final VoidCallback onHistory;

  const _QuickActionsSection({
    required this.onScan,
    required this.onRewards,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan',
                color: Colors.blue,
                onTap: onScan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.card_giftcard_rounded,
                label: 'Rewards',
                color: Colors.purple,
                onTap: onRewards,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                icon: Icons.history_rounded,
                label: 'History',
                color: Colors.teal,
                onTap: onHistory,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// RECENT ACTIVITY
// ============================================================================

class _RecentActivitySection extends StatelessWidget {
  final List<RecyclingLog> logs;
  final VoidCallback onSeeAll;

  const _RecentActivitySection({
    required this.logs,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (logs.isEmpty)
          _EmptyActivityState()
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                return _ActivityListTile(log: logs[index]);
              },
            ),
          ),
      ],
    );
  }
}

class _EmptyActivityState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.recycling_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No activity yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start scanning trash to earn rewards!',
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

class _ActivityListTile extends StatelessWidget {
  final RecyclingLog log;

  const _ActivityListTile({required this.log});

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
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final wasteType = log.wasteType;
    final icon = _getWasteIcon(wasteType);
    final color = _getWasteColor(wasteType);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        wasteType.isNotEmpty
            ? '${wasteType[0].toUpperCase()}${wasteType.substring(1)}'
            : 'Unknown',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        _formatDate(log.createdAt),
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '+${log.rewardPoints} pts',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.green,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// REWARDS GUIDE SECTION
// ============================================================================

class _RewardsGuideSection extends StatelessWidget {
  const _RewardsGuideSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How It Works',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              _GuideCard(
                icon: Icons.camera_alt_outlined,
                title: 'Scan & Sort',
                description: 'Take a photo of your trash to identify the type',
                color: Colors.blue,
              ),
              SizedBox(width: 12),
              _GuideCard(
                icon: Icons.verified_outlined,
                title: 'Get Verified',
                description: 'Higher confidence & verified disposal = more pts',
                color: Colors.purple,
              ),
              SizedBox(width: 12),
              _GuideCard(
                icon: Icons.card_giftcard,
                title: 'Earn Rewards',
                description: 'Redeem points for vouchers, perks & crypto',
                color: Colors.teal,
              ),
              SizedBox(width: 12),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Points breakdown
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Points per Item',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  _PointsBadge(label: 'Plastic', points: 10, color: Colors.blue),
                  _PointsBadge(
                      label: 'Paper', points: 5, color: Color(0xFFF59E0B)),
                  _PointsBadge(label: 'Metal', points: 15, color: Colors.grey),
                  _PointsBadge(label: 'Glass', points: 12, color: Colors.teal),
                  _PointsBadge(label: 'E-Waste', points: 25, color: Colors.red),
                  _PointsBadge(
                      label: 'Organic', points: 8, color: Colors.green),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Browse Rewards CTA
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RewardsPage()),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.blue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.redeem_outlined),
            label: const Text(
              'Browse Rewards',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _GuideCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              height: 1.3,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  final String label;
  final int points;
  final Color color;

  const _PointsBadge({
    required this.label,
    required this.points,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$points',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BLOCKCHAIN HEALTH DEBUG SECTION
// ============================================================================

class _BlockchainHealthSection extends StatelessWidget {
  final BlockchainHealth health;

  const _BlockchainHealthSection({required this.health});

  @override
  Widget build(BuildContext context) {
    final ok = health.ok;
    final statusColor = ok ? Colors.green : Colors.red;
    final statusIcon = ok ? Icons.link : Icons.link_off;
    final statusLabel = ok ? 'Connected' : 'Disconnected';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Blockchain Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _HealthRow(
                label: 'Status',
                value: statusLabel,
                icon: statusIcon,
                color: statusColor,
              ),
              if (health.chainId != null)
                _HealthRow(
                  label: 'Chain ID',
                  value: '${health.chainId}',
                  icon: Icons.tag,
                ),
              if (health.blockNumber != null)
                _HealthRow(
                  label: 'Block',
                  value: '#${health.blockNumber}',
                  icon: Icons.view_module,
                ),
              if (health.contractAddress != null)
                _HealthRow(
                  label: 'Contract',
                  value: health.shortContract,
                  icon: Icons.article_outlined,
                  copyValue: health.contractAddress,
                ),
              if (health.signerAddress != null)
                _HealthRow(
                  label: 'Signer',
                  value: health.shortSigner,
                  icon: Icons.person_outline,
                  copyValue: health.signerAddress,
                ),
              if (health.error != null)
                _HealthRow(
                  label: 'Error',
                  value: health.error!,
                  icon: Icons.error_outline,
                  color: Colors.red,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? copyValue;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.copyValue,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (copyValue != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: copyValue!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Icon(Icons.copy, size: 14, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }
}
