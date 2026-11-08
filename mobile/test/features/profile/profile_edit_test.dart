import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/features/auth/domain/auth_user.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_providers.dart';
import 'package:hvp_forging/features/fighter_record/presentation/providers/fighter_record_providers.dart';
import 'package:hvp_forging/features/profile/presentation/providers/profile_providers.dart';
import 'package:hvp_forging/features/profile/presentation/widgets/profile_details.dart';

import '../../helpers/fake_auth_repository.dart';
import '../../helpers/test_harness.dart';
import '../fighter_record/fixtures.dart';
import 'fixtures.dart';

/// Mirrors what AccountPanel shows, so the test sees the signed-in user change.
class _WhoAmI extends ConsumerWidget {
  const _WhoAmI();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text('me:${ref.watch(currentUserProvider)?.fullName}');
}

Future<void> _pump(WidgetTester tester, FakeProfileRepository repo) async {
  await pumpHvp(
    tester,
    const Scaffold(
      body: SingleChildScrollView(
          child: Column(children: <Widget>[_WhoAmI(), ProfileDetails()])),
    ),
    overrides: <Override>[
      profileRepositoryProvider.overrideWithValue(repo),
      fighterRecordRepositoryProvider
          .overrideWithValue(FakeFighterRecordRepository()),
      authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(restored: makeUser(AppRole.student))),
    ],
  );
  await tester.pumpAndSettle();
}

Future<void> _startEdit(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Chỉnh sửa hồ sơ'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, int field, String text) =>
    tester.enterText(find.byType(TextFormField).at(field), text);

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('LƯU THAY ĐỔI'));
  await tester.tap(find.text('LƯU THAY ĐỔI'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'saving sends only the changed field, refreshes and updates the signed-in user',
      (tester) async {
    final repo = FakeProfileRepository();
    repo.onUpdate = (_) async => sampleProfile(fullName: 'Nguyễn Văn B');
    await _pump(tester, repo);
    await _startEdit(tester);
    final loadsBefore = repo.getCalls;
    await _type(tester, 0, 'Nguyễn Văn B');
    await _save(tester);

    expect(repo.updates.single, <String, Object?>{'fullName': 'Nguyễn Văn B'});
    expect(find.text('Đã cập nhật hồ sơ.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('me:Nguyễn Văn B'), findsOneWidget);
    expect(repo.getCalls, loadsBefore + 1);
  });

  testWidgets('clearing the email sends null', (tester) async {
    final repo = FakeProfileRepository();
    await _pump(tester, repo);
    await _startEdit(tester);
    await _type(tester, 2, '');
    await _save(tester);

    expect(repo.updates.single, <String, Object?>{'email': null});
  });

  testWidgets('no change closes the form without a request', (tester) async {
    final repo = FakeProfileRepository();
    await _pump(tester, repo);
    await _startEdit(tester);
    await _save(tester);

    expect(repo.updates, isEmpty);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('invalid input is rejected locally', (tester) async {
    final repo = FakeProfileRepository();
    await _pump(tester, repo);
    await _startEdit(tester);
    await _type(tester, 0, '');
    await _type(tester, 1, '12');
    await _type(tester, 2, 'not-an-email');
    await _save(tester);

    expect(find.text('Vui lòng nhập họ tên.'), findsOneWidget);
    expect(find.text('Số điện thoại chưa hợp lệ.'), findsOneWidget);
    expect(find.text('Email chưa đúng định dạng.'), findsOneWidget);
    expect(repo.updates, isEmpty);
  });

  testWidgets('PHONE_TAKEN and EMAIL_TAKEN show under their field',
      (tester) async {
    final repo = FakeProfileRepository();
    await _pump(tester, repo);
    await _startEdit(tester);

    repo.onUpdate = (_) async => throw const ApiException(
        code: 'PHONE_TAKEN', message: 'Số điện thoại này đã được đăng ký.');
    await _type(tester, 1, '0900000000');
    await _save(tester);
    expect(find.text('Số điện thoại này đã được đăng ký.'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));

    repo.onUpdate = (_) async => throw const ApiException(
        code: 'EMAIL_TAKEN', message: 'Email này đã được đăng ký.');
    await _type(tester, 2, 'b@example.com');
    await _save(tester);
    expect(find.text('Email này đã được đăng ký.'), findsOneWidget);
    expect(find.text('Số điện thoại này đã được đăng ký.'), findsNothing);
  });

  testWidgets('CONTACT_REQUIRED shows the API message', (tester) async {
    final repo = FakeProfileRepository();
    repo.onUpdate = (_) async => throw const ApiException(
        code: 'CONTACT_REQUIRED',
        message: 'Cần giữ lại ít nhất số điện thoại hoặc email.');
    await _pump(tester, repo);
    await _startEdit(tester);
    await _type(tester, 1, '');
    await _type(tester, 2, '');
    await _save(tester);

    expect(find.text('Cần giữ lại ít nhất số điện thoại hoặc email.'),
        findsOneWidget);
    expect(
        repo.updates.single, <String, Object?>{'phone': null, 'email': null});
  });

  testWidgets('Huỷ leaves edit mode without saving', (tester) async {
    final repo = FakeProfileRepository();
    await _pump(tester, repo);
    await _startEdit(tester);
    await tester.ensureVisible(find.text('HUỶ'));
    await tester.tap(find.text('HUỶ'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNothing);
    expect(repo.updates, isEmpty);
  });
}
