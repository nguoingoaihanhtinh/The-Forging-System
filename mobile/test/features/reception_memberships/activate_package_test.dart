import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/reception_memberships/presentation/screens/member_detail_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'desk_harness.dart';
import 'members_test.dart' show detailRoutes;

Map<String, dynamic> typeJson(String id, String name,
        {int? price = 8900000, bool trial = false}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'isTrial': trial,
      'priceVnd': price,
      'durationDays': 84,
      'totalSessions': 36
    };

Map<String, Reply> _routes({Reply? activate, List<dynamic>? types}) =>
    <String, Reply>{
      ...detailRoutes(),
      'GET /package-types': (_) => okEnvelope(types ??
          <dynamic>[
            typeJson('p1', 'BOOK I'),
            typeJson('p2', 'Trải nghiệm', price: null, trial: true)
          ]),
      'POST /members/m1/memberships': activate ??
          (_) => okEnvelope(<String, dynamic>{
                'mode': 'ACTIVATED',
                'message': 'Đã kích hoạt BOOK I.'
              }, status: 201),
    };

Future<void> _open(WidgetTester tester, Desk desk) async {
  await pumpHvp(tester, const MemberDetailScreen(memberId: 'm1'),
      overrides: desk.overrides);
  await tester.pumpAndSettle();
  await tester.tap(find.text('KÍCH HOẠT / GIA HẠN GÓI'));
  await tester.pumpAndSettle();
}

Finder _next() => find.widgetWithText(HvpButton, 'TIẾP TỤC');
Finder _confirm() => find.widgetWithText(HvpButton, 'XÁC NHẬN & KÍCH HOẠT GÓI');

void main() {
  testWidgets('MEM-16 choose a package, then the photo, then activate',
      (tester) async {
    final desk = Desk(_routes());
    await _open(tester, desk);

    expect(find.text('8.900.000đ · 84 ngày · 36 buổi'), findsOneWidget);
    expect(find.text('chưa có giá · 84 ngày · 36 buổi'), findsOneWidget);
    expect(find.text('GÓI TRẢI NGHIỆM'), findsOneWidget);
    expect(tester.widget<HvpButton>(_next()).onPressed, isNull);

    await tester.tap(find.text('BOOK I').last);
    await tester.pump();
    await tester.tap(_next());
    await tester.pumpAndSettle();
    expect(find.text('XÁC NHẬN ĐÃ THU PHÍ'), findsOneWidget);
    expect(find.text('Nguyễn Thị Lan · BOOK I'), findsOneWidget);
    expect(tester.widget<HvpButton>(_confirm()).onPressed, isNull);

    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pumpAndSettle();

    expect(
        desk.calls('POST /members/m1/memberships').single.data,
        <String, dynamic>{
          'packageTypeId': 'p1',
          'paymentEvidenceUrl': kEvidenceUrl
        });
    expect(find.text('Đã kích hoạt BOOK I.'), findsOneWidget);
    expect(desk.calls('GET /members/m1'), hasLength(2));
  });

  testWidgets('MEM-16 shows the API refusal in the photo step', (tester) async {
    final desk = Desk(_routes(
        activate: (_) => errorEnvelope(409, 'MEMBERSHIP_ALREADY_SCHEDULED',
            'Học viên đã có gói nối tiếp đang chờ kích hoạt.')));
    await _open(tester, desk);
    await tester.tap(find.text('BOOK I').last);
    await tester.pump();
    await tester.tap(_next());
    await tester.pumpAndSettle();
    await tester.tap(find.text('CHỌN ẢNH'));
    await tester.pump();
    await tester.tap(_confirm());
    await tester.pumpAndSettle();
    expect(find.text('Học viên đã có gói nối tiếp đang chờ kích hoạt.'),
        findsOneWidget);
  });

  testWidgets('MEM-16 empty package list and error', (tester) async {
    await _open(tester, Desk(_routes(types: <dynamic>[])));
    expect(find.text('Hiện chưa có gói nào đang bán.'), findsOneWidget);
  });
}
