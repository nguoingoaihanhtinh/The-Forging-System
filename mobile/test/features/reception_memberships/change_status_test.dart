import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/reception_memberships/domain/member_rules.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/member_detail_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'desk_harness.dart';
import 'members_test.dart' show detailRoutes, profileJson;

Future<void> _open(WidgetTester tester, Desk desk) async {
  await pumpHvp(tester, const MemberDetailScreen(memberId: 'm1'),
      overrides: desk.overrides);
  await tester.pumpAndSettle();
}

void main() {
  test('reception is only ever offered freeze and unfreeze', () {
    expect(nextStatusFor('ACTIVE'), 'FROZEN');
    expect(nextStatusFor('FROZEN'), 'ACTIVE');
    expect(nextStatusFor('INACTIVE'), isNull);
  });

  testWidgets('MEM-18 freezes an active account with a required reason',
      (tester) async {
    final desk = Desk(<String, Reply>{
      ...detailRoutes(),
      'POST /members/m1/status': (_) => jsonResponse(204, <String, dynamic>{}),
    });
    await _open(tester, desk);
    expect(find.text('MỞ LẠI (UNFREEZE)'), findsNothing);

    await tester.tap(find.widgetWithText(HvpButton, 'ĐÓNG BĂNG'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'ĐÓNG BĂNG').last);
    await tester.pump();
    expect(find.text('Vui lòng nhập lý do trước khi đổi trạng thái.'),
        findsWidgets);
    expect(desk.calls('POST /members/m1/status'), isEmpty);

    await tester.enterText(find.byType(TextField).last, 'Đi công tác');
    await tester.tap(find.widgetWithText(HvpButton, 'ĐÓNG BĂNG').last);
    await tester.pumpAndSettle();
    expect(desk.calls('POST /members/m1/status').single.data,
        <String, dynamic>{'status': 'FROZEN', 'reason': 'Đi công tác'});
    expect(find.text('Đã đóng băng tài khoản.'), findsOneWidget);
    expect(desk.calls('GET /members/m1'), hasLength(2));
  });

  testWidgets('MEM-18 reopens a frozen account and shows an API refusal',
      (tester) async {
    final desk = Desk(<String, Reply>{
      ...detailRoutes(
          profile: profileJson(status: 'FROZEN', reason: 'Đi công tác')),
      'POST /members/m1/status': (_) =>
          errorEnvelope(422, 'INACTIVE_PRIORITY', 'Tài khoản đang INACTIVE.'),
    });
    await _open(tester, desk);
    expect(find.widgetWithText(HvpButton, 'ĐÓNG BĂNG'), findsNothing);

    await tester.tap(find.text('MỞ LẠI (UNFREEZE)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Đã quay lại');
    await tester.tap(find.widgetWithText(HvpButton, 'MỞ LẠI').last);
    await tester.pumpAndSettle();
    expect(desk.calls('POST /members/m1/status').single.data,
        <String, dynamic>{'status': 'ACTIVE', 'reason': 'Đã quay lại'});
    expect(find.text('Tài khoản đang INACTIVE.'), findsOneWidget);
  });

  testWidgets('MEM-18 an inactive account has no status button for reception',
      (tester) async {
    await _open(
        tester, Desk(detailRoutes(profile: profileJson(status: 'INACTIVE'))));
    expect(find.widgetWithText(HvpButton, 'ĐÓNG BĂNG'), findsNothing);
    expect(find.text('MỞ LẠI (UNFREEZE)'), findsNothing);
  });
}
