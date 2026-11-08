class CreateArmoryTierInput {
  const CreateArmoryTierInput({
    required this.code,
    required this.name,
    required this.minMarks,
    this.maxMarks,
    required this.sortOrder,
  });

  final String code;
  final String name;
  final int minMarks;
  final int? maxMarks;
  final int sortOrder;
}

class AdminArmoryTier {
  const AdminArmoryTier({
    required this.code,
    required this.name,
    required this.minMarks,
    this.maxMarks,
    required this.sortOrder,
  });

  final String code;
  final String name;
  final int minMarks;
  final int? maxMarks;
  final int sortOrder;
}

class UpdateArmoryTierInput {
  const UpdateArmoryTierInput({
    required this.name,
    required this.minMarks,
    this.maxMarks,
    required this.sortOrder,
    required this.reason,
  });

  final String name;
  final int minMarks;
  final int? maxMarks;
  final int sortOrder;
  final String reason;
}

class AdminArmoryReward {
  const AdminArmoryReward({
    required this.id,
    required this.sku,
    required this.name,
    this.description,
    this.imageUrl,
    this.tierCode,
    required this.marksCost,
    required this.stock,
    this.perMemberLimit,
    this.limitPeriod,
    this.minRankId,
    this.pickupDays,
    this.saleStartsAt,
    this.saleEndsAt,
    required this.isActive,
  });

  final String id;
  final String sku;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? tierCode;
  final int marksCost;
  final int stock;
  final int? perMemberLimit;
  final String? limitPeriod;
  final String? minRankId;
  final int? pickupDays;
  final DateTime? saleStartsAt;
  final DateTime? saleEndsAt;
  final bool isActive;
}

class AdminArmoryRewardPage {
  const AdminArmoryRewardPage({
    required this.items,
    required this.page,
    required this.totalPages,
  });

  final List<AdminArmoryReward> items;
  final int page;
  final int totalPages;
}

class CreateArmoryRewardInput {
  const CreateArmoryRewardInput({
    required this.sku,
    required this.name,
    required this.marksCost,
    required this.stock,
    this.description,
    this.imageUrl,
    this.tierCode,
    this.perMemberLimit,
    this.limitPeriod,
    this.minRankId,
    this.pickupDays,
    this.saleStartsAt,
    this.saleEndsAt,
    this.isActive = true,
  });

  final String sku;
  final String name;
  final int marksCost;
  final int stock;
  final String? description;
  final String? imageUrl;
  final String? tierCode;
  final int? perMemberLimit;
  final String? limitPeriod;
  final String? minRankId;
  final int? pickupDays;
  final DateTime? saleStartsAt;
  final DateTime? saleEndsAt;
  final bool isActive;
}

class UpdateArmoryRewardInput extends CreateArmoryRewardInput {
  const UpdateArmoryRewardInput({
    required super.sku,
    required super.name,
    required super.marksCost,
    required super.stock,
    required this.reason,
    super.description,
    super.imageUrl,
    super.tierCode,
    super.perMemberLimit,
    super.limitPeriod,
    super.minRankId,
    super.pickupDays,
    super.saleStartsAt,
    super.saleEndsAt,
    super.isActive,
  });

  final String reason;
}

abstract interface class AdminArmoryRepository {
  Future<List<AdminArmoryTier>> tiers();
  Future<void> createTier(CreateArmoryTierInput input);
  Future<void> updateTier(String code, UpdateArmoryTierInput input);
  Future<AdminArmoryRewardPage> rewards({
    String? query,
    String? tierCode,
    bool? isActive,
    int page = 1,
  });
  Future<AdminArmoryReward> reward(String id);
  Future<void> createReward(CreateArmoryRewardInput input);
  Future<void> updateReward(String id, UpdateArmoryRewardInput input);
}
