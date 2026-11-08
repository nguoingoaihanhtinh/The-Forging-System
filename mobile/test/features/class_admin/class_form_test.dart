import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/class_admin/domain/class_models.dart';
import 'package:hvp_forging/features/class_admin/domain/class_rules.dart';
import 'package:hvp_forging/features/class_admin/presentation/widgets/class_form_sheet.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';
import 'support.dart';

Future<void> tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byType(HvpButton));
  await tester.tap(find.byType(HvpButton));
  await tester.pumpAndSettle();
}

void main() {
  test('changesFrom lists only edited fields; weekdays compare by value', () {
    final before = ClassDraft.of(sampleClass);
    expect(before.changesFrom(before), isEmpty);
    final edited = ClassDraft(
      branchId: before.branchId,
      name: 'Boxing tối',
      sessionTypeCode: before.sessionTypeCode,
      weekdays: const <int>[1, 3, 5],
      startTime: before.startTime,
      durationMinutes: before.durationMinutes,
      capacity: null,
      defaultCoachId: before.defaultCoachId,
      isActive: before.isActive,
    );
    expect(edited.changesFrom(before),
        <String, Object?>{'name': 'Boxing tối', 'capacity': null});
  });

  test('validators', () {
    expect(validateClassName('  '), 'Nhập tên lớp.');
    expect(validateStartTime('6:30'), isNotNull);
    expect(validateStartTime('23:59'), isNull);
    expect(validateDuration('0'), isNotNull);
    expect(validateCapacity(''), isNull);
    expect(validateCapacity('1001'), isNotNull);
  });

  test('repository create posts the draft, update patches only changes',
      () async {
    final t = buildRepo(
        (o) => okEnvelope(classJson, status: o.method == 'POST' ? 201 : 200));
    await t.repo.create(ClassDraft.of(sampleClass));
    await t.repo.update('c1', <String, Object?>{'capacity': null});
    expect(t.adapter.requests[0].method, 'POST');
    expect(t.adapter.requests[0].path, '/admin/classes');
    expect((t.adapter.requests[0].data as Map)['weekdays'], <int>[1, 3, 5]);
    expect(t.adapter.requests[1].method, 'PATCH');
    expect(t.adapter.requests[1].path, '/admin/classes/c1');
    expect(t.adapter.requests[1].data, <String, Object?>{'capacity': null});
  });

  group('sheet', () {
    Future<FakeClassRepository> show(WidgetTester tester,
        {ClassSummary? existing, FakeClassRepository? repo}) async {
      final fake = repo ?? FakeClassRepository();
      await pumpHvp(
        tester,
        Scaffold(
            body: Builder(
                builder: (c) => TextButton(
                    onPressed: () => showClassForm(c, existing: existing),
                    child: const Text('open')))),
        overrides: classOverrides(fake),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return fake;
    }

    testWidgets('empty name shows the error and nothing is sent',
        (tester) async {
      final repo = await show(tester);
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Nhập tên lớp.'), findsOneWidget);
      expect(repo.created, isEmpty);
    });

    testWidgets('create sends the draft and toasts', (tester) async {
      final repo = await show(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Boxing sáng');
      await tester.tap(find.text('Chọn chi nhánh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HVP Quận 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T2'));
      await tester.tap(find.text('T4'));
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(repo.created.single.weekdays, <int>[1, 3]);
      expect(repo.created.single.capacity, isNull);
      expect(find.text('Đã tạo lớp.'), findsOneWidget);
    });

    testWidgets('edit sends only the changed field', (tester) async {
      final repo = await show(tester, existing: sampleClass);
      await tester.enterText(find.byType(TextFormField).first, 'Boxing tối');
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(repo.updated.single, <String, Object?>{'name': 'Boxing tối'});
      expect(find.text('Đã cập nhật lớp.'), findsOneWidget);
    });

    testWidgets('API error stays in the sheet', (tester) async {
      final repo = FakeClassRepository()
        ..createError = const ApiException(
            code: 'BRANCH_INACTIVE', message: 'Chi nhánh đã ngừng hoạt động');
      await show(tester, existing: null, repo: repo);
      await tester.enterText(find.byType(TextFormField).first, 'X');
      await tester.tap(find.text('Chọn chi nhánh'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('HVP Quận 7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T2'));
      await tapSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('Chi nhánh đã ngừng hoạt động'), findsOneWidget);
    });
  });
}
