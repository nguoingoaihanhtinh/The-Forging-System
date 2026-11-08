class ArmoryWallet {
  const ArmoryWallet({
    required this.marksBalance,
    required this.marksHeld,
    required this.marksAvailable,
    required this.canRedeem,
  });

  final int marksBalance;
  final int marksHeld;
  final int marksAvailable;
  final bool canRedeem;
}

abstract interface class ArmoryWalletRepository {
  Future<ArmoryWallet> wallet();
}
