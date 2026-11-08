/// The rotating check-in code of a branch, as the front-desk screen shows it (docs/api/checkin.md).
class BranchCheckinCode {
  const BranchCheckinCode({
    required this.branchId,
    required this.branchCode,
    required this.payload,
    required this.shortCode,
    required this.ttlSeconds,
    required this.expiresAt,
    required this.serverOffset,
  });

  final String branchId;
  final String branchCode;

  /// Text to draw as the QR.
  final String payload;

  /// The 6 digits for members who cannot scan.
  final String shortCode;
  final int ttlSeconds;

  /// When the server stops showing this code and starts the next.
  final DateTime expiresAt;

  /// Server clock minus this device's clock when the code was fetched. The countdown runs on the server's
  /// time, so a tablet whose clock is off still switches codes exactly when the server does.
  final Duration serverOffset;

  /// Time left of this code at [deviceNow]; zero or negative once it is over.
  Duration remainingAt(DateTime deviceNow) => expiresAt.difference(deviceNow.toUtc().add(serverOffset));

  /// 0..1 share of the code's life still left, for the countdown bar.
  double fractionLeftAt(DateTime deviceNow) {
    final total = ttlSeconds * 1000;
    if (total <= 0) return 0;
    return (remainingAt(deviceNow).inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// `482913` -> `482 913`, easier to read out loud.
  String get shortCodeSpaced => shortCode.length == 6 ? '${shortCode.substring(0, 3)} ${shortCode.substring(3)}' : shortCode;
}

abstract interface class BranchCodeRepository {
  Future<BranchCheckinCode> current(String branchId);
}
