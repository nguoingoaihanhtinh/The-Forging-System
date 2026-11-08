class StaffRedemption {
  const StaffRedemption({
    required this.id,
    required this.redemptionCode,
    required this.memberId,
    required this.memberCode,
    required this.memberFullName,
    required this.rewardId,
    required this.rewardName,
    required this.rewardSku,
    required this.pickupBranchId,
    required this.pickupBranchName,
    required this.marksCost,
    required this.status,
    required this.requestedAt,
    this.reason,
  });

  final String id;
  final String redemptionCode;
  final String memberId;
  final String memberCode;
  final String memberFullName;
  final String rewardId;
  final String rewardName;
  final String rewardSku;
  final String pickupBranchId;
  final String pickupBranchName;
  final int marksCost;
  final String status;
  final DateTime requestedAt;
  final String? reason;
}

class StaffRedemptionPage {
  const StaffRedemptionPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<StaffRedemption> items;
  final int page;
  final int totalPages;
  final int total;
}

abstract interface class StaffRedemptionRepository {
  Future<StaffRedemptionPage> list(
      {String? status, String? query, int page = 1});
  Future<void> approve(String redemptionId, {String? reason});
  Future<void> deliver(String redemptionId,
      {String? reason, String? evidenceUrl});
  Future<void> reject(String redemptionId, {required String reason});
}
