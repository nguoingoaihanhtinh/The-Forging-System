import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/armory/data/wallet_repository.dart';
import '../../helpers/scripted_adapter.dart';

void main() {
  test('ARM-10 repository loads available and held Marks', () async {
    final dio = createApiDio(
      config: const AppConfig(
          apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(
          accessToken: 'member-token', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter(
      (_) => okEnvelope(<String, dynamic>{
        'marksBalance': 500,
        'marksHeld': 120,
        'marksAvailable': 380,
        'canRedeem': true,
      }),
    );
    dio.httpClientAdapter = adapter;

    final wallet = await ArmoryWalletRepositoryImpl(ApiClient(dio)).wallet();

    expect(adapter.requests.single.path, '/me/armory/wallet');
    expect(wallet.marksBalance, 500);
    expect(wallet.marksHeld, 120);
    expect(wallet.marksAvailable, 380);
    expect(wallet.canRedeem, isTrue);
  });
}
