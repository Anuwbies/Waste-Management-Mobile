/// API response wrapper for authentication
class AuthResponse {
  final String? token;
  final UserData? user;
  final String? message;
  final bool success;

  AuthResponse({
    this.token,
    this.user,
    this.message,
    this.success = true,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String?,
      user: json['user'] != null 
          ? UserData.fromJson(json['user'] as Map<String, dynamic>) 
          : null,
      message: json['message'] as String?,
      success: json['message'] != 'Invalid email or password',
    );
  }
}

class UserData {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final String? walletAddress;
  final int totalRewards;

  UserData({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    this.walletAddress,
    this.totalRewards = 0,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      walletAddress: json['walletAddress'] as String?,
      totalRewards: (json['totalRewards'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'walletAddress': walletAddress,
      'totalRewards': totalRewards,
    };
  }
}
