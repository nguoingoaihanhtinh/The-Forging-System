/// The printable (static) QR of a branch, `GET /branches/:id/qr`. Not a check-in code.
class BranchQr {
  const BranchQr({
    required this.branchId,
    required this.code,
    required this.qrVersion,
    required this.payload,
  });

  final String branchId;
  final String code;
  final String qrVersion;

  /// `HVP|<code>|<qrVersion>`, the text to draw as the QR.
  final String payload;
}
