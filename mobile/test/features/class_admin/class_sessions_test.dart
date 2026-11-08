import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/class_admin/domain/class_models.dart';
import 'package:hvp_forging/features/class_admin/domain/class_rules.dart';
import 'package:hvp_forging/features/class_admin/presentation/widgets/class_sessions_section.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'support.dart';

void main() {
  test('canCancelSession: only SCHEDULED and not started', () {
    final now = DateTime(2026, 11, 8, 10);
    final later = now.add(const Duration(hours: 1));
    expect(canCancelSession('SCHEDULED', later, now), isTrue);
    expect(
        canCancelSession(
            'SCHEDULED', now.subtract(const Duration(minutes: 1)), now),
        isFalse);
    expect(canCancelSession('CANCELLED', later, now), isFalse);
    expect(canCancelSession('IN_PROGRESS', later, now), isFalse);
  });

  test('repository: sessions and cancel body', () async {
    final t = buildRepo((o) => o.method == 'GET'
        ? okEnvelope(<dynamic>[
            <String, dynamic>{
              'id': 's1',
              'title': 'Boxing tối',
              'startsAt': '2026-03-02T11:30:00.000Z',
              'status': 'SCHEDULED',
              'isExam': true,
              'attendeeCount': 2,
              'coach': <String, dynamic>{'id': 'k1', 'fullName': 'Coach A'},
            }
          ])
        : okEnvelope(<String, dynamic>{'status': 'CANCELLED'}));
    final list = await t.repo.sessions('c1');
    expect(list.single.coachName, 'Coach A');
    expect(list.single.startsAt, DateTime.utc(2026, 3, 2, 11, 30));
    await t.repo.cancelSession('s1', ' Nghỉ lễ ');
    expect(t.adapter.requests[1].path, '/sessions/s1/cancel');
    expect(t.adapter.requests[1].data, <String, dynamic>{'reason': 'Nghỉ lễ'});
  });

  Future<FakeClassRepository> show(WidgetTester tester,
      [FakeClassRepository? repo]) async {
    final fake = repo ?? FakeClassRepository();
    await pumpHvp(
        tester,
        const Scaffold(
            body: SingleChildScrollView(
                child: ClassSessionsSection(classId: 'c1'))),
        overrides: classOverrides(fake));
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('cancel is offered only on future scheduled sessions',
      (tester) async {
    await show(tester);
    expect(find.text('Huỷ buổi'), findsOneWidget);
    expect(find.text('ĐÃ HUỶ'), findsOneWidget);
  });

  testWidgets('a reason is required', (tester) async {
    final repo = await show(tester);
    await tester.tap(find.text('Huỷ buổi'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ BUỔI'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập lý do huỷ.'), findsOneWidget);
    expect(repo.cancelled, isEmpty);
  });

  testWidgets('cancel sends the reason and toasts', (tester) async {
    final repo = await show(tester);
    await tester.tap(find.text('Huỷ buổi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Nghỉ lễ');
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ BUỔI'));
    await tester.pumpAndSettle();
    expect(repo.cancelled, <String>['s1|Nghỉ lễ']);
    expect(find.text('Đã huỷ buổi.'), findsOneWidget);
  });

  testWidgets('API error is shown in the sheet', (tester) async {
    final repo = FakeClassRepository()
      ..cancelError = const ApiException(
          code: 'SESSION_NOT_CANCELLABLE',
          message: 'Chỉ huỷ được buổi chưa diễn ra.');
    await show(tester, repo);
    await tester.tap(find.text('Huỷ buổi'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'x');
    await tester.tap(find.widgetWithText(HvpButton, 'HUỶ BUỔI'));
    await tester.pumpAndSettle();
    expect(find.text('Chỉ huỷ được buổi chưa diễn ra.'), findsOneWidget);
  });

  testWidgets('empty and error states', (tester) async {
    await show(tester, FakeClassRepository()..sessionList = <ClassSession>[]);
    expect(find.text('Chưa có buổi tập nào.'), findsOneWidget);
  });
}
