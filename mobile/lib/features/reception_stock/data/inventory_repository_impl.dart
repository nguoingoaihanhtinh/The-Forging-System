import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/inventory.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  InventoryRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<InventoryRewardPage> rewards({String query = '', int page = 1}) async {
    final response = await _api.get('/staff/armory/rewards',
        query: <String, dynamic>{
          'page': page,
          'limit': 20,
          if (query.trim().isNotEmpty) 'q': query.trim(),
        });
    final meta = PageMeta.fromJson(response.meta);
    return InventoryRewardPage(
      items: response.dataList
          .map((value) => _reward(asMap(value)))
          .toList(growable: false),
      page: meta.page,
      totalPages: meta.totalPages,
      total: meta.total,
    );
  }

  @override
  Future<InventoryMovementPage> movements({
    String? rewardId,
    String? movementType,
    int page = 1,
  }) async {
    final response = await _api.get('/staff/armory/inventory/movements',
        query: <String, dynamic>{
          'page': page,
          'limit': 20,
          if (rewardId != null) 'rewardId': rewardId,
          if (movementType != null) 'movementType': movementType,
        });
    final meta = PageMeta.fromJson(response.meta);
    return InventoryMovementPage(
      items: response.dataList
          .map((value) => _movement(asMap(value)))
          .toList(growable: false),
      page: meta.page,
      totalPages: meta.totalPages,
      total: meta.total,
    );
  }

  @override
  Future<void> adjust({
    required String rewardId,
    required String movementType,
    required int quantity,
    required String reason,
  }) =>
      _api.post('/staff/armory/inventory/movements',
          body: <String, dynamic>{
            'rewardId': rewardId,
            'movementType': movementType,
            'quantity': quantity,
            'reason': reason.trim(),
          });

  InventoryReward _reward(JsonMap json) => InventoryReward(
        id: str(json, 'id'),
        sku: str(json, 'sku'),
        name: str(json, 'name'),
        stock: intOf(json, 'stock'),
        isActive: boolOf(json, 'isActive', true),
      );

  InventoryMovement _movement(JsonMap json) => InventoryMovement(
        id: str(json, 'id'),
        rewardId: str(json, 'rewardId'),
        rewardSku: str(json, 'rewardSku'),
        rewardName: str(json, 'rewardName'),
        movementType: str(json, 'movementType'),
        quantity: intOf(json, 'quantity'),
        createdAt: dateOrNull(json, 'createdAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        redemptionId: strOrNull(json, 'redemptionId'),
        actorName: strOrNull(json, 'actorName'),
        reason: strOrNull(json, 'reason'),
      );
}
