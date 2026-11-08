import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/wallet.dart';

class ArmoryWalletRepositoryImpl implements ArmoryWalletRepository {
  ArmoryWalletRepositoryImpl(this.api);
  final ApiClient api;

  @override
  Future<ArmoryWallet> wallet() async {
    final response = await api.get('/me/armory/wallet');
    final json = response.dataMap;
    return ArmoryWallet(
      marksBalance: intOf(json, 'marksBalance'),
      marksHeld: intOf(json, 'marksHeld'),
      marksAvailable: intOf(json, 'marksAvailable'),
      canRedeem: boolOf(json, 'canRedeem'),
    );
  }
}
