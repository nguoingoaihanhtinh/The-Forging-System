import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';

import '../../helpers/scripted_adapter.dart';
import 'desk_harness.dart';
import 'renewal_requests_test.dart';

Map<String, Reply> _routes({Reply? cancel}) {
  var cancelled = false;
  return <String, Reply>{
    'GET /renewal-requests': (_) => okEnvelope(
        cancelled ? <dynamic>[] : <dynamic>[renewalJson('r1', 'Nguyễn Văn A')],
        meta: pageMeta(1, cancelled ? 0 : 1)),
    'POST /renewal-requests/r1/cancel': (o) {
      final reply = cancel?.call(o);
      if (reply != null) return reply;
      cancelled = true;
      return okEnvelope(renewalJson('r1', 'Nguyễn Văn A',
          status: 'CANCELLED', reason: 'Sai gói'));
    },
  };
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(HvpButton, 'HUỶ YÊU CẦU'));
  await tester.pumpAndSettle();
}

Finder _confirm() => find.widgetWithText(HvpButton, 'HUỶ YÊU CẦU').last;

void main() {
  testWidgets('MEM-14 an empty reason is refused without calling the API',
      (tester) async {
    final desk = Desk(_routes());
    await pumpTab(tester, desk);
    await _openSheet(tester);
    expect(find.text('HUỶ YÊU CẦU GIA HẠN'), findsOneWidget);

    await tester.tap(_confirm());
    await tester.pump();
    expect(find.text('Vui lòng nhập lý do huỷ.'), findsWidgets);
    expect(desk.calls('POST /renewal-requests/r1/cancel'), isEmpty);
  });

  testWidgets(
      'MEM-14 cancels with the reason, toasts and drops the request from the inbox',
      (tester) async {
    final desk = Desk(_routes());
    await pumpTab(tester, desk);
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField).last, '  Sai gói  ');
    await tester.tap(_confirm());
    await tester.pumpAndSettle();

    expect(desk.calls('POST /renewal-requests/r1/cancel').single.data,
        <String, dynamic>{'reason': 'Sai gói'});
    expect(
        find.text('Đã huỷ yêu cầu — học viên được thông báo.'), findsOneWidget);
    expect(find.text('Nguyễn Văn A'), findsNothing);
  });

  testWidgets(
      'MEM-14 shows the API error and reloads when the request was already handled',
      (tester) async {
    final desk = Desk(_routes(
        cancel: (_) => errorEnvelope(
            409, 'RENEWAL_ALREADY_HANDLED', 'Yêu cầu này đã được xử lý.')));
    await pumpTab(tester, desk);
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField).last, 'Sai gói');
    await tester.tap(_confirm());
    await tester.pumpAndSettle();

    expect(find.text('Yêu cầu này đã được xử lý.'), findsOneWidget);
    expect(desk.calls('GET /renewal-requests'), hasLength(2));
  });
}
