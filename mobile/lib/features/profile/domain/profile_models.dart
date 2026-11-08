/// Personal profile of the signed-in member (`GET /me/profile`). Pure Dart.
library;

class MemberProfile {
  const MemberProfile({
    required this.userId,
    required this.fullName,
    required this.status,
    this.email,
    this.phone,
    this.avatarUrl,
    this.homeBranchName,
    this.joinedAt,
    this.currentRankId,
  });

  final String userId;
  final String fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? homeBranchName;
  final DateTime? joinedAt;

  /// `ACTIVE`, `FROZEN` or `INACTIVE`.
  final String status;
  final String? currentRankId;

  String get statusLabel {
    switch (status) {
      case 'ACTIVE':
        return 'Hoạt động';
      case 'FROZEN':
        return 'Đóng băng';
      case 'INACTIVE':
        return 'Không hoạt động';
      default:
        return status;
    }
  }
}
