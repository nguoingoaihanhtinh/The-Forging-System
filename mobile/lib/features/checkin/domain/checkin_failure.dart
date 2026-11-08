import '../../../core/error/api_exception.dart';
import 'checkin_outcome.dart';

/// A refused check-in as the result screen needs it: what happened, what to offer, and the facts to show.
class CheckinFailure {
  const CheckinFailure({
    required this.code,
    required this.message,
    required this.action,
    this.isNetwork = false,
    this.opensAt,
    this.closesAt,
    this.branchNames = const <String>[],
  });

  /// Reads the backend error (`details: { action, opensAt?, closesAt?, branches? }`, docs/api/checkin.md).
  factory CheckinFailure.from(ApiException error) {
    final details = error.details is Map ? error.details! as Map<dynamic, dynamic> : const <dynamic, dynamic>{};
    final branches = details['branches'];
    return CheckinFailure(
      code: error.code,
      message: error.message,
      action: checkinActionOf(error),
      isNetwork: error.isNetwork,
      opensAt: DateTime.tryParse('${details['opensAt'] ?? ''}'),
      closesAt: DateTime.tryParse('${details['closesAt'] ?? ''}'),
      branchNames: branches is List
          ? branches.whereType<Map<dynamic, dynamic>>().map((b) => '${b['name'] ?? ''}').where((n) => n.isNotEmpty).toList(growable: false)
          : const <String>[],
    );
  }

  final String code;

  /// Vietnamese sentence from the server, ready to show.
  final String message;
  final CheckinAction action;

  /// The request never got an answer (no connection, timeout): the code itself may be fine.
  final bool isNetwork;
  final DateTime? opensAt;
  final DateTime? closesAt;

  /// Where the member's sessions are, when the code was for another branch.
  final List<String> branchNames;

  String get title => checkinFailureTitle(code, network: isNetwork);
}

/// Short heading for the result screen, by error code; any other error gets a general one.
String checkinFailureTitle(String code, {bool network = false}) {
  if (network) return 'MẤT KẾT NỐI';
  switch (code) {
    case 'CHECKIN_CODE_INVALID':
      return 'MÃ KHÔNG HỢP LỆ';
    case 'CHECKIN_CODE_EXPIRED':
      return 'MÃ ĐÃ HẾT HẠN';
    case 'NO_SESSION_TODAY':
      return 'HÔM NAY KHÔNG CÓ BUỔI TẬP';
    case 'CHECKIN_WRONG_BRANCH':
      return 'SAI CHI NHÁNH';
    case 'CHECKIN_SESSION_NOT_ELIGIBLE':
      return 'KHÔNG TÌM THẤY BUỔI TẬP';
    case 'OVERLAPS_CHECKED_IN':
      return 'TRÙNG GIỜ VỚI BUỔI KHÁC';
    case 'NOT_YET_OPEN':
      return 'CHƯA ĐẾN GIỜ CHECK-IN';
    case 'CHECKIN_CLOSED':
      return 'ĐÃ HẾT GIỜ CHECK-IN';
    case 'ACCOUNT_INACTIVE':
      return 'TÀI KHOẢN KHÔNG HOẠT ĐỘNG';
    case 'ACCOUNT_RESTRICTED':
      return 'TÀI KHOẢN ĐANG ĐÓNG BĂNG';
    case 'MEMBERSHIP_INVALID':
      return 'GÓI TẬP KHÔNG HỢP LỆ';
    default:
      return 'CHƯA CHECK-IN ĐƯỢC';
  }
}
