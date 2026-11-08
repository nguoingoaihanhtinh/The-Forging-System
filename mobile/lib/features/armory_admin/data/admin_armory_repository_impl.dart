import '../../../core/network/api_client.dart';
import '../domain/admin_armory_repository.dart';

class AdminArmoryRepositoryImpl implements AdminArmoryRepository {
  AdminArmoryRepositoryImpl(this._api);

  final ApiClient _api;

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
}
