import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/features/checkin/domain/checkin_failure.dart';
import 'package:hvp_forging/features/checkin/domain/checkin_outcome.dart';

void main() {
  test('CHK-09 reads the action and the facts from the error details', () {
    final f = CheckinFailure.from(const ApiException(
      code: 'CHECKIN_WRONG_BRANCH',
      message: 'Sai chi nhánh.',
      statusCode: 422,
      details: <String, dynamic>{
        'action': 'GO_TO_BRANCH',
        'opensAt': '2026-11-02T10:45:00.000Z',
        'closesAt': '2026-11-02T11:30:00.000Z',
        'branches': <dynamic>[
          <String, dynamic>{'id': 'q7', 'name': 'Riverside'},
          <String, dynamic>{'id': 'q1'},
        ],
      },
    ));
    expect(f.action, CheckinAction.goToBranch);
    expect(f.opensAt, DateTime.utc(2026, 11, 2, 10, 45));
    expect(f.closesAt, DateTime.utc(2026, 11, 2, 11, 30));
    expect(f.branchNames, <String>['Riverside']); // an entry without a name is skipped
    expect(f.message, 'Sai chi nhánh.');
    expect(f.isNetwork, isFalse);
  });

  test('copes with an error that has no details at all', () {
    final f = CheckinFailure.from(const ApiException(code: 'X', message: 'm'));
    expect(f.action, CheckinAction.none);
    expect(f.opensAt, isNull);
    expect(f.branchNames, isEmpty);
    expect(f.title, 'CHƯA CHECK-IN ĐƯỢC');
  });

  test('every check-in error code has its own heading, a lost connection another', () {
    const codes = <String, String>{
      'CHECKIN_CODE_INVALID': 'MÃ KHÔNG HỢP LỆ',
      'CHECKIN_CODE_EXPIRED': 'MÃ ĐÃ HẾT HẠN',
      'NO_SESSION_TODAY': 'HÔM NAY KHÔNG CÓ BUỔI TẬP',
      'CHECKIN_WRONG_BRANCH': 'SAI CHI NHÁNH',
      'CHECKIN_SESSION_NOT_ELIGIBLE': 'KHÔNG TÌM THẤY BUỔI TẬP',
      'OVERLAPS_CHECKED_IN': 'TRÙNG GIỜ VỚI BUỔI KHÁC',
      'NOT_YET_OPEN': 'CHƯA ĐẾN GIỜ CHECK-IN',
      'CHECKIN_CLOSED': 'ĐÃ HẾT GIỜ CHECK-IN',
      'ACCOUNT_INACTIVE': 'TÀI KHOẢN KHÔNG HOẠT ĐỘNG',
      'ACCOUNT_RESTRICTED': 'TÀI KHOẢN ĐANG ĐÓNG BĂNG',
      'MEMBERSHIP_INVALID': 'GÓI TẬP KHÔNG HỢP LỆ',
    };
    codes.forEach((code, title) => expect(checkinFailureTitle(code), title, reason: code));
    expect(checkinFailureTitle('CHECKIN_CODE_EXPIRED', network: true), 'MẤT KẾT NỐI');
    expect(checkinFailureTitle('NEVER_HEARD_OF_IT'), 'CHƯA CHECK-IN ĐƯỢC');
  });
}
