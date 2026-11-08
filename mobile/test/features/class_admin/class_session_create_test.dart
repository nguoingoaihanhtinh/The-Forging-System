import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/class_admin/domain/class_models.dart';
import 'package:hvp_forging/features/class_admin/domain/class_rules.dart';
import 'package:hvp_forging/features/class_admin/presentation/widgets/exam_session_sheet.dart';
import 'package:hvp_forging/features/class_admin/presentation/widgets/session_form_sheet.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'support.dart';

void main() {
  test(
      'vietnamInstant: 18:30 Vietnam is 11:30Z, and midnight crosses to the previous UTC day',
      () {
    expect(vietnamInstant(DateTime(2026, 3, 3), '18:30'),
        DateTime.utc(2026, 3, 3, 11, 30));
    expect(vietnamInstant(DateTime(2026, 3, 3), '00:15'),
        DateTime.utc(2026, 3, 2, 17, 15));
  });

  test('repository: POST /sessions body and exam-sessions body', () async {
    final t =
        buildRepo((o) => okEnvelope(<String, dynamic>{'id': 's'}, status: 201));
    await t.repo.createSession(SessionDraft(
      sessionTypeCode: 'ACADEMY',
      branchId: 'b1',
      startsAt: DateTime.utc(2026, 3, 3, 11, 30),
      durationMinutes: 60,
      title: ' Lesson ',
      isExam: false,
      capacity: 10,
    ));
    await t.repo.createExamSession('c1', '2026-03-04', title: ' ');
    final body = t.adapter.requests[0].data as Map;
    expect(t.adapter.requests[0].path, '/sessions');
    expect(body['startsAt'], '2026-03-03T11:30:00.000Z');
    expect(body['title'], 'Lesson');
    expect(body['capacity'], 10);
    expect(body.containsKey('coachId'), isFalse);
    expect(body.containsKey('notes'), isFalse);
    expect(t.adapter.requests[1].path, '/classes/c1/exam-sessions');
    expect(t.adapter.requests[1].data, <String, dynamic>{'date': '2026-03-04'});
  });

  Future<FakeClassRepository> open(
      WidgetTester tester, Widget Function(BuildContext) opener) async {
    final fake = FakeClassRepository();
    await pumpHvp(tester, Scaffold(body: Builder(builder: opener)),
        overrides: classOverrides(fake));
    await tester.tap(find.byType(TextButton));
    await tester.pumpAndSettle();
    return fake;
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(HvpButton));
    await tester.tap(find.byType(HvpButton));
    await tester.pumpAndSettle();
  }

  testWidgets('exam: date is required, then POST with the picked date',
      (tester) async {
    final repo = await open(
        tester,
        (c) => TextButton(
            onPressed: () =>
                showExamSheet(c, classId: 'c1', className: 'Boxing sáng'),
            child: const Text('open')));
    expect(find.text('Boxing sáng'), findsOneWidget);
    await submit(tester);
    expect(find.text('Vui lòng chọn ngày.'), findsOneWidget);
    expect(repo.exams, isEmpty);
    await tester.tap(find.byType(TextField).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Kiểm tra cấp 1');
    await submit(tester);
    expect(
        repo.exams.single, matches(r'^c1\|\d{4}-\d{2}-\d{2}\|Kiểm tra cấp 1$'));
    expect(find.text('Đã tạo buổi kiểm tra.'), findsOneWidget);
  });

  testWidgets('session form: missing fields block the request', (tester) async {
    final repo = await open(
        tester,
        (c) => TextButton(
            onPressed: () => showSessionForm(c), child: const Text('open')));
    await submit(tester);
    expect(find.text('Nhập tiêu đề buổi.'), findsOneWidget);
    expect(find.text('Vui lòng chọn chi nhánh.'), findsOneWidget);
    expect(repo.sessionsCreated, isEmpty);
  });

  testWidgets('session form: a day today at a past time is rejected locally',
      (tester) async {
    final repo = await open(
        tester,
        (c) => TextButton(
            onPressed: () => showSessionForm(c), child: const Text('open')));
    await tester.enterText(find.byType(TextFormField).first, 'PT');
    await tester.tap(find.text('Chọn chi nhánh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HVP Quận 7'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).at(1));
    await tester.tap(find.byType(TextField).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '00:00');
    await submit(tester);
    expect(find.text('Không thể tạo buổi trong quá khứ.'), findsOneWidget);
    expect(repo.sessionsCreated, isEmpty);
  });

  testWidgets('session form: valid input sends the Vietnam instant',
      (tester) async {
    final repo = await open(
        tester,
        (c) => TextButton(
            onPressed: () => showSessionForm(c), child: const Text('open')));
    await tester.enterText(find.byType(TextFormField).first, 'Buổi Academy');
    await tester.tap(find.text('Chọn chi nhánh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HVP Quận 7'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField).at(1));
    await tester.tap(find.byType(TextField).at(1));
    await tester.pumpAndSettle();
    // Next month, same day, so the time is always in the future.
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), '18:30');
    await submit(tester);
    final draft = repo.sessionsCreated.single;
    expect(draft.startsAt.toUtc().hour, 11);
    expect(draft.startsAt.toUtc().minute, 30);
    expect(draft.sessionTypeCode, 'ACADEMY');
    expect(find.text('Đã tạo buổi.'), findsOneWidget);
  });
}
