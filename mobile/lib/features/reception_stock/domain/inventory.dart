class InventoryReward {
  const InventoryReward({
    required this.id,
    required this.sku,
    required this.name,
    required this.stock,
    required this.isActive,
  });

  final String id;
  final String sku;
  final String name;
  final int stock;
  final bool isActive;
}

class InventoryRewardPage {
  const InventoryRewardPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<InventoryReward> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
}

class InventoryMovement {
  const InventoryMovement({
    required this.id,
    required this.rewardId,
    required this.rewardSku,
    required this.rewardName,
    required this.movementType,
    required this.quantity,
    required this.createdAt,
    this.redemptionId,
    this.actorName,
    this.reason,
  });

  final String id;
  final String rewardId;
  final String rewardSku;
  final String rewardName;
  final String movementType;
  final int quantity;
  final DateTime createdAt;
  final String? redemptionId;
  final String? actorName;
  final String? reason;

  bool get isInbound => movementType == 'IN';
}

class InventoryMovementPage {
  const InventoryMovementPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<InventoryMovement> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;
}

abstract interface class InventoryRepository {
  Future<InventoryRewardPage> rewards({String query = '', int page = 1});

  Future<InventoryMovementPage> movements({
    String? rewardId,
    String? movementType,
    int page = 1,
  });

  Future<void> adjust({
    required String rewardId,
    required String movementType,
    required int quantity,
    required String reason,
  });
}
