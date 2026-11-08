import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/admin_armory_repository.dart';

class AdminArmoryRepositoryImpl implements AdminArmoryRepository {
  AdminArmoryRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<AdminArmoryTier>> tiers() async {
    final response = await _api.get('/admin/armory/tiers');
    return response.dataList.map((value) {
      final json = asMap(value);
      return AdminArmoryTier(
        code: str(json, 'code'),
        name: str(json, 'name'),
        minMarks: intOf(json, 'minMarks'),
        maxMarks: json['maxMarks'] == null ? null : intOf(json, 'maxMarks'),
        sortOrder: intOf(json, 'sortOrder'),
      );
    }).toList(growable: false);
  }

  @override
  Future<void> createTier(CreateArmoryTierInput input) async {
    await _api.post('/admin/armory/tiers', body: <String, dynamic>{
      'code': input.code.trim().toUpperCase(),
      'name': input.name.trim(),
      'minMarks': input.minMarks,
      'maxMarks': input.maxMarks,
      'sortOrder': input.sortOrder,
    });
  }

  @override
  Future<void> updateTier(String code, UpdateArmoryTierInput input) async {
    await _api.patch('/admin/armory/tiers/$code', body: <String, dynamic>{
      'name': input.name.trim(),
      'minMarks': input.minMarks,
      'maxMarks': input.maxMarks,
      'sortOrder': input.sortOrder,
      'reason': input.reason.trim(),
    });
  }

  @override
  Future<AdminArmoryRewardPage> rewards({
    String? query,
    String? tierCode,
    bool? isActive,
    int page = 1,
  }) async {
    final response =
        await _api.get('/admin/armory/rewards', query: <String, dynamic>{
      'page': page,
      'limit': 20,
      if (query?.trim().isNotEmpty ?? false) 'q': query!.trim(),
      if (tierCode != null) 'tierCode': tierCode,
      if (isActive != null) 'isActive': isActive,
    });
    final meta = PageMeta.fromJson(response.meta);
    return AdminArmoryRewardPage(
      items: response.dataList
          .map((value) => _reward(asMap(value)))
          .toList(growable: false),
      page: meta.page,
      totalPages: meta.totalPages,
    );
  }

  @override
  Future<AdminArmoryReward> reward(String id) async =>
      _reward((await _api.get('/admin/armory/rewards/$id')).dataMap);

  @override
  Future<void> createReward(CreateArmoryRewardInput input) async {
    await _api.post('/admin/armory/rewards', body: _rewardBody(input));
  }

  @override
  Future<void> updateReward(String id, UpdateArmoryRewardInput input) async {
    final body = _rewardBody(input)..remove('sku');
    await _api.patch('/admin/armory/rewards/$id', body: <String, dynamic>{
      ...body,
      'reason': input.reason.trim(),
    });
  }

  Map<String, dynamic> _rewardBody(CreateArmoryRewardInput input) =>
      <String, dynamic>{
        'sku': input.sku.trim().toUpperCase(),
        'name': input.name.trim(),
        'description': input.description?.trim().isEmpty ?? true
            ? null
            : input.description!.trim(),
        'imageUrl': input.imageUrl?.trim().isEmpty ?? true
            ? null
            : input.imageUrl!.trim(),
        'tierCode': input.tierCode,
        'marksCost': input.marksCost,
        'stock': input.stock,
        'perMemberLimit': input.perMemberLimit,
        'limitPeriod': input.limitPeriod,
        'minRankId': input.minRankId,
        'pickupDays': input.pickupDays,
        'saleStartsAt': input.saleStartsAt?.toUtc().toIso8601String(),
        'saleEndsAt': input.saleEndsAt?.toUtc().toIso8601String(),
        'isActive': input.isActive,
      };

  AdminArmoryReward _reward(Map<String, dynamic> json) => AdminArmoryReward(
        id: str(json, 'id'),
        sku: str(json, 'sku'),
        name: str(json, 'name'),
        description: strOrNull(json, 'description'),
        imageUrl: strOrNull(json, 'imageUrl'),
        tierCode: strOrNull(json, 'tierCode'),
        marksCost: intOf(json, 'marksCost'),
        stock: intOf(json, 'stock'),
        perMemberLimit: json['perMemberLimit'] == null
            ? null
            : intOf(json, 'perMemberLimit'),
        limitPeriod: strOrNull(json, 'limitPeriod'),
        minRankId: strOrNull(json, 'minRankId'),
        pickupDays:
            json['pickupDays'] == null ? null : intOf(json, 'pickupDays'),
        saleStartsAt: dateOrNull(json, 'saleStartsAt'),
        saleEndsAt: dateOrNull(json, 'saleEndsAt'),
        isActive: json['isActive'] as bool? ?? false,
      );
}
