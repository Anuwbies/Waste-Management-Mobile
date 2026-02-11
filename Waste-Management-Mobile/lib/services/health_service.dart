import '../config/api_config.dart';
import 'api_client.dart';

/// Blockchain health diagnostic information
class BlockchainHealth {
  final bool ok;
  final int? chainId;
  final int? blockNumber;
  final String? contractAddress;
  final String? signerAddress;
  final String? rpcUrl;
  final String? error;
  final Map<String, dynamic> raw;

  BlockchainHealth({
    this.ok = false,
    this.chainId,
    this.blockNumber,
    this.contractAddress,
    this.signerAddress,
    this.rpcUrl,
    this.error,
    this.raw = const {},
  });

  factory BlockchainHealth.fromJson(Map<String, dynamic> json) {
    return BlockchainHealth(
      ok: json['ok'] as bool? ?? false,
      chainId: (json['chainId'] as num?)?.toInt(),
      blockNumber: (json['blockNumber'] as num?)?.toInt(),
      contractAddress: json['contractAddress'] as String?,
      signerAddress: json['signerAddress'] as String?,
      rpcUrl: json['rpcUrl'] as String?,
      error: json['error'] as String?,
      raw: json,
    );
  }

  /// Short address for display
  String get shortContract {
    if (contractAddress == null || contractAddress!.length < 12) return 'N/A';
    return '${contractAddress!.substring(0, 6)}...${contractAddress!.substring(contractAddress!.length - 4)}';
  }

  String get shortSigner {
    if (signerAddress == null || signerAddress!.length < 12) return 'N/A';
    return '${signerAddress!.substring(0, 6)}...${signerAddress!.substring(signerAddress!.length - 4)}';
  }
}

/// Service for health / diagnostics endpoints
class HealthService {
  // Singleton
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final ApiClient _api = ApiClient();

  /// GET /health/blockchain
  Future<BlockchainHealth> getBlockchainHealth() async {
    try {
      final response = await _api.get(ApiConfig.blockchainHealth);
      return BlockchainHealth.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to check blockchain health');
    }
  }
}
