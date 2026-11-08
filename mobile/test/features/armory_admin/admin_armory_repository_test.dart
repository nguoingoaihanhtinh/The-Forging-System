import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/armory_admin/data/admin_armory_repository_impl.dart';
import 'package:hvp_forging/features/armory_admin/domain/admin_armory_repository.dart';

import '../../helpers/scripted_adapter.dart';

void main() {
  test('creates a tier and does not send SKU while updating a reward',
      () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(
        const StoredTokens(accessToken: 'admin-token', refreshToken: 'refresh'),
      ),
    );
    final adapter = ScriptedAdapter((_) => okEnvelope(<String, dynamic>{}));
    dio.httpClientAdapter = adapter;
    final repository = AdminArmoryRepositoryImpl(ApiClient(dio));

    await repository.createTier(const CreateArmoryTierInput(
      code: 'gold',
      name: 'Vàng',
      minMarks: 100,
      sortOrder: 2,
    ));
    await repository.updateReward(
      'reward-1',
      const UpdateArmoryRewardInput(
        sku: 'UNCHANGED-SKU',
        name: 'Găng tập',
        marksCost: 200,
        stock: 3,
        reason: 'Điều chỉnh tồn kho',
      ),
    );

    expect(adapter.requests[0].path, '/admin/armory/tiers');
    expect(adapter.requests[0].data, <String, dynamic>{
      'code': 'GOLD',
      'name': 'Vàng',
      'minMarks': 100,
      'maxMarks': null,
      'sortOrder': 2,
    });
    expect(adapter.requests[1].path, '/admin/armory/rewards/reward-1');
    expect((adapter.requests[1].data as Map<String, dynamic>)['sku'], isNull);
    expect((adapter.requests[1].data as Map<String, dynamic>)['reason'],
        'Điều chỉnh tồn kho');
  });
}
