import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pagination.dart';
import '../models/reward_models.dart';
import '../services/api_client.dart';
import '../services/rewards_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage>
    with SingleTickerProviderStateMixin {
  final RewardsService _rewardsService = RewardsService();

  late TabController _tabController;
  late Future<_RewardsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _dataFuture = _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_RewardsData> _loadData() async {
    final results = await Future.wait([
      _rewardsService.getBalance().catchError((_) => RewardBalance()),
      _rewardsService.getHistory(limit: 50).catchError(
        (_) => RewardHistoryResponse(
          history: [],
          pagination: Pagination(page: 1, limit: 50, total: 0, totalPages: 0),
        ),
      ),
      _rewardsService.getStats().catchError((_) => RewardStats()),
      _rewardsService
          .getOptions()
          .catchError((_) => RewardOptionsResponse()),
    ]);

    return _RewardsData(
      balance: results[0] as RewardBalance,
      history: results[1] as RewardHistoryResponse,
      stats: results[2] as RewardStats,
      options: results[3] as RewardOptionsResponse,
    );
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<void> _handleRedeem(BuildContext ctx, RewardOption option) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text('Redeem ${option.name}?'),
        content: Text(
          'This will deduct ${option.pointsCost} points from your balance.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Redeem', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final result = await _rewardsService.redeem(rewardType: option.id);

      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            '${result.rewardName} redeemed! -${result.pointsRedeemed} pts'
            '${result.txHash != null ? ' (tx: ${result.txHash!.substring(0, 10)}...)' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Redemption failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTransaction(RewardHistoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from history?'),
        content: const Text(
            'This will only remove the record from your display. It does not affect your actual balance.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Use the referenceId (RewardTransaction ID) if available, otherwise item.id
      final idToDelete = item.id ?? item.id;
      await _rewardsService.deleteTransaction(idToDelete);
      if (!mounted) return;
      _refresh(); // reload to get updated history
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Record removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove: $e')),
      );
    }
  }

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
          'Rewards',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<_RewardsData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Failed to load rewards'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Balance Card
                    _WalletCard(balance: data.balance),
                    const SizedBox(height: 24),

                    // Stats Section
                    _StatsSection(stats: data.stats),
                    const SizedBox(height: 24),

                    // Available Rewards Section (dynamic from API)
                    _AvailableRewardsSection(
                      options: data.options,
                      onRedeem: (option) => _handleRedeem(context, option),
                    ),
                    const SizedBox(height: 24),

                    // Reward History
                    _RewardHistorySection(
                      history: data.history.history,
                      onDelete: _deleteTransaction,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// DATA MODEL
// ============================================================================

class _RewardsData {
  final RewardBalance balance;
  final RewardHistoryResponse history;
  final RewardStats stats;
  final RewardOptionsResponse options;

  _RewardsData({
    required this.balance,
    required this.history,
    required this.stats,
    required this.options,
  });
}

// ============================================================================
// WALLET CARD
// ============================================================================

class _WalletCard extends StatelessWidget {
  final RewardBalance balance;

  const _WalletCard({required this.balance});

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
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  balance.source == 'chain'
                      ? Icons.verified_outlined
                      : Icons.cloud_off_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  balance.source == 'chain'
                      ? 'Verified on-chain'
                      : 'Off-chain (cached)',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
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
// STATS SECTION
// ============================================================================

class _StatsSection extends StatelessWidget {
  final RewardStats stats;

  const _StatsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Stats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.stars_rounded,
                      label: 'Total Earned',
                      value: '${stats.totalEarned}',
                      color: Colors.amber,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.grey.shade200,
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.redeem_rounded,
                      label: 'Redeemed',
                      value: '${stats.totalRedeemed}',
                      color: Colors.deepOrange,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.grey.shade200,
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.recycling_rounded,
                      label: 'Items Recycled',
                      value: '${stats.recordCount}',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _getTotalCount(RewardStats stats) {
    int total = 0;
    stats.statsByType.forEach((_, value) {
      total += value.count;
    });
    return total;
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// AVAILABLE REWARDS
// ============================================================================

class _AvailableRewardsSection extends StatelessWidget {
  final RewardOptionsResponse options;
  final void Function(RewardOption option) onRedeem;

  const _AvailableRewardsSection({
    required this.options,
    required this.onRedeem,
  });

  /// Fallback cards when API returns no options
  static const _fallbackCards = [
    _FallbackReward('Coffee Voucher', 500, Icons.coffee, Color(0xFF8B4513)),
    _FallbackReward('Shopping Discount', 1000, Icons.shopping_bag, Colors.pink),
    _FallbackReward('ECO Token', 2500, Icons.token, Colors.green),
    _FallbackReward('Plant a Tree', 5000, Icons.park, Colors.teal),
  ];

  @override
  Widget build(BuildContext context) {
    final hasOptions = options.options.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Rewards',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 175,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: hasOptions ? options.options.length : _fallbackCards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (hasOptions) {
                final opt = options.options[index];
                return _RewardCard(
                  title: opt.name,
                  points: opt.pointsCost,
                  description: opt.description,
                  canAfford: opt.canAfford,
                  imageIcon: _iconForReward(opt.id),
                  color: _colorForReward(opt.id),
                  onTap: opt.canAfford ? () => onRedeem(opt) : null,
                );
              } else {
                final fb = _fallbackCards[index];
                return _RewardCard(
                  title: fb.title,
                  points: fb.points,
                  imageIcon: fb.icon,
                  color: fb.color,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  IconData _iconForReward(String id) {
    switch (id.toLowerCase()) {
      case 'coffee':
        return Icons.coffee;
      case 'discount':
      case 'shopping':
        return Icons.shopping_bag;
      case 'eco_token':
      case 'token':
        return Icons.token;
      case 'plant_tree':
      case 'tree':
        return Icons.park;
      default:
        return Icons.card_giftcard;
    }
  }

  Color _colorForReward(String id) {
    switch (id.toLowerCase()) {
      case 'coffee':
        return const Color(0xFF8B4513);
      case 'discount':
      case 'shopping':
        return Colors.pink;
      case 'eco_token':
      case 'token':
        return Colors.green;
      case 'plant_tree':
      case 'tree':
        return Colors.teal;
      default:
        return Colors.blue;
    }
  }
}

class _FallbackReward {
  final String title;
  final int points;
  final IconData icon;
  final Color color;
  const _FallbackReward(this.title, this.points, this.icon, this.color);
}

class _RewardCard extends StatelessWidget {
  final String title;
  final int points;
  final String? description;
  final bool canAfford;
  final IconData imageIcon;
  final Color color;
  final VoidCallback? onTap;

  const _RewardCard({
    required this.title,
    required this.points,
    required this.imageIcon,
    required this.color,
    this.description,
    this.canAfford = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: canAfford ? color.withValues(alpha: 0.4) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(imageIcon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$points pts',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (canAfford) ...[
                  const Spacer(),
                  Icon(Icons.check_circle, size: 16, color: color),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// REWARD HISTORY
// ============================================================================

class _RewardHistorySection extends StatelessWidget {
  final List<RewardHistoryItem> history;
  final void Function(RewardHistoryItem item) onDelete;

  const _RewardHistorySection({
    required this.history,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reward History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.history, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  'No reward history yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          )
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
              itemCount: history.length > 10 ? 10 : history.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final item = history[index];
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (direction) async {
                    onDelete(item);
                    return false;
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: _HistoryTile(item: item),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final RewardHistoryItem item;

  const _HistoryTile({required this.item});

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'recycling':
        return Icons.recycling;
      case 'bonus':
        return Icons.star;
      case 'redemption':
        return Icons.redeem;
      default:
        return Icons.monetization_on;
    }
  }

  Color _getColor(String type) {
    switch (type.toLowerCase()) {
      case 'recycling':
        return Colors.green;
      case 'bonus':
        return Colors.amber;
      case 'redemption':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon(item.type);
    final color = _getColor(item.type);
    final isPositive = item.points >= 0;

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
        item.description.isNotEmpty ? item.description : item.type,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatDate(item.createdAt),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      trailing: Text(
        '${isPositive ? '+' : ''}${item.points}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: isPositive ? Colors.green : Colors.red,
        ),
      ),
    );
  }
}
