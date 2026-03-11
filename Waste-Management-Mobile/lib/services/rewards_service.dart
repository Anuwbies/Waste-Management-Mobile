import 'package:flutter/widgets.dart';

import '../config/api_config.dart';
import '../models/reward_models.dart';
import 'api_client.dart';

/// Service for rewards management
class RewardsService {
  // Singleton pattern
  static final RewardsService _instance = RewardsService._internal();
  factory RewardsService() => _instance;
  RewardsService._internal();

  final ApiClient _api = ApiClient();

  /// Get current reward balance
  /// Backend returns: { balance, chainStats: { balance, totalEarned, totalRedeemed, recordCount }, walletAddress }
  Future<RewardBalance> getBalance() async {
    try {
      final response = await _api.get(ApiConfig.rewardsBalance);
      return RewardBalance.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load reward balance');
    }
  }

  /// Get reward history
  Future<RewardHistoryResponse> getHistory({
    int page = 1,
    int limit = 20,
    String? type,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (type != null) {
        queryParams['type'] = type;
      }

      final response = await _api.get(
        ApiConfig.rewardsHistory,
        queryParams: queryParams,
      );

      return RewardHistoryResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load reward history');
    }
  }

  /// Get reward statistics
  Future<RewardStats> getStats() async {
    try {
      final response = await _api.get(ApiConfig.rewardsStats);
      return RewardStats.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load reward statistics');
    }
  }

  /// Get available reward redemption options
  /// Backend returns: { currentBalance, options: [{ id, name, pointsCost, description, canAfford }] }
  Future<RewardOptionsResponse> getOptions() async {
    try {
      final response = await _api.get(ApiConfig.rewardsOptions);
      return RewardOptionsResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to load reward options');
    }
  }

  /// Redeem a reward
  /// Backend expects: { rewardType, customPoints? }
  /// Returns: { message, redemption: { id, redemptionId, rewardType, rewardName, pointsRedeemed, txHash, status }, newBalance }
  Future<RedemptionResponse> redeem({
    required String rewardType,
    int? customPoints,
  }) async {
    try {
      final body = <String, dynamic>{
        'rewardType': rewardType,
      };
      if (customPoints != null) {
        body['customPoints'] = customPoints;
      }

      final response = await _api.post(
        ApiConfig.rewardsRedeem,
        body: body,
      );

      return RedemptionResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to redeem reward');
    }
  }

  /// Delete a reward transaction by ID
  Future<void> deleteTransaction(String id) async {
    try {
      await _api.delete('/rewards/history/$id');
      debugPrint('[RewardsService] Transaction $id deleted');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to delete reward history: $e');
    }
  }
}
