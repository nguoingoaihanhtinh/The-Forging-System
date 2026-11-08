import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/wallet_repository.dart';
import '../domain/wallet.dart';

final armoryWalletRepositoryProvider = Provider<ArmoryWalletRepository>(
  (ref) => ArmoryWalletRepositoryImpl(ref.watch(apiClientProvider)),
);

final armoryWalletProvider = FutureProvider.autoDispose<ArmoryWallet>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(armoryWalletRepositoryProvider).wallet();
});
