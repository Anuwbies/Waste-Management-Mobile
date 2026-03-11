import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/recycling_log.dart';
import '../models/scan_session.dart';
import '../config/api_config.dart';
import 'api_client.dart';

/// Service for recycling activity logging
class RecyclingService {
  // Singleton pattern
  static final RecyclingService _instance = RecyclingService._internal();
  factory RecyclingService() => _instance;
  RecyclingService._internal();

  final ApiClient _api = ApiClient();

  /// Log a recycling activity (simple)
  Future<RecyclingResponse> logRecycling({
    required String wasteType,
    int quantity = 1,
  }) async {
    try {
      final response = await _api.post(
        ApiConfig.recycle,
        body: {
          'wasteType': wasteType,
          'quantity': quantity,
        },
      );

      return RecyclingResponse.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to log recycling activity');
    }
  }

  /// Submit recycling event with full classification context
  /// This is the primary method for the scan pipeline
  /// 
  /// Backend POST /recycle expects JSON:
  ///   { wasteType, quantity?, imageData? (base64), metadata? }
  /// Returns:
  ///   { message, log: { id, eventId, eventHash, wasteType, quantity,
  ///     rewardPoints, txHash, status, chainId }, totalRewards, wallet }
  Future<RewardDecision> submitRecyclingEvent({
    required File imageFile,
    required CnnClassification classification,
    required DisposalSuggestion suggestion,
    String? idempotencyKey,
  }) async {
    try {
      // Build JSON body matching backend contract
      final body = <String, dynamic>{
        'wasteType': classification.label,
        'quantity': 1,
        'metadata': {
          'confidence': classification.confidence,
          'binType': suggestion.binType,
          'source': 'cnn',
          'isRecyclable': suggestion.isRecyclable,
          'idempotencyKey': idempotencyKey ??
              DateTime.now().millisecondsSinceEpoch.toString(),
        },
      };

      // Optionally attach base64 image for server-side eventHash dedup
      // Only for small images to avoid large payloads
      try {
        final imageBytes = await imageFile.readAsBytes();
        if (imageBytes.length <= ApiConfig.maxUploadSize) {
          body['imageData'] = base64Encode(imageBytes);
        }
      } catch (_) {
        // Skip image data — server can still process without it
      }

      final response = await _api.post(ApiConfig.recycle, body: body);

      // Parse response through RewardDecision.fromJson
      // which handles the { log: { ... }, totalRewards, wallet } shape
      return RewardDecision.fromJson(response);
    } on ApiException catch (e) {
      // 409 = duplicate event already processed
      if (e.statusCode == 409) {
        throw ApiException(
          'This item was already submitted. Scan a new item!',
          statusCode: 409,
          data: e.data,
        );
      }
      rethrow;
    } catch (e) {
      throw ApiException('Failed to submit recycling event: $e');
    }
  }

  /// Get recycling logs with optional waste-type filter
  Future<RecyclingLogsResponse> getLogs({
    int page = 1,
    int limit = 20,
    String? wasteType,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (wasteType != null && wasteType.isNotEmpty) {
        queryParams['wasteType'] = wasteType;
      }

      final response = await _api.get(
        ApiConfig.recycleLogs,
        queryParams: queryParams,
      );

      final result = RecyclingLogsResponse.fromJson(response);
      if (kDebugMode) {
        print('[RecyclingService] getLogs => '
            '${result.logs.length} items, '
            'page ${result.pagination.page}/${result.pagination.totalPages}, '
            'total ${result.pagination.total}');
      }
      return result;
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) print('[RecyclingService] getLogs error: $e');
      throw ApiException('Failed to load recycling logs');
    }
  }

  /// Delete a recycling log by ID
  Future<void> deleteLog(String id) async {
    try {
      await _api.delete('/recycle/logs/$id');
      debugPrint('[RecyclingService] Log $id deleted');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to delete recycling log: $e');
    }
  }
}
