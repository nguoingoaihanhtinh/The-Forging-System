import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/error_state.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/fighter_record/presentation/providers/fighter_record_providers.dart';
import 'package:hvp_forging/features/profile/domain/profile_models.dart';
import 'package:hvp_forging/features/profile/presentation/providers/profile_providers.dart';
import 'package:hvp_forging/features/profile/presentation/widgets/profile_details.dart';

import '../../helpers/test_harness.dart';
import '../fighter_record/fixtures.dart';
import 'fixtures.dart';

Future<void> _pump(WidgetTester tester, FakeProfileRepository repo) => pumpHvp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ProfileDetails())),
      overrides: <Override>[
        profileRepositoryProvider.overrideWithValue(repo),
        fighterRecordRepositoryProvider
            .overrideWithValue(FakeFighterRecordRepository()),
        currentUserIdProvider.overrideWithValue('user-student'),
      ],
    );

void main() {
  testWidgets('shows the read-only rows with the rank from the fighter record',
      (tester) async {
    await _pump(tester, FakeProfileRepository());
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('0912345678'), findsOneWidget);
    expect(find.text('a@example.com'), findsOneWidget);
    expect(find.text('01/10/2026'), findsOneWidget);
    expect(find.text('THE DISCIPLINED'), findsOneWidget);
    expect(find.text('Hoạt động'), findsOneWidget);
    expect(find.text('HVP Boxing - The Corner'), findsOneWidget);
    for (final label in <String>[
      'Ngày tham gia',
      'Hạng hiện tại',
      'Trạng thái tài khoản',
      'Chi nhánh chính'
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('missing email shows a dash', (tester) async {
    final repo = FakeProfileRepository()
      ..onGet = () async => sampleProfile(email: null);
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    final completer = Completer<MemberProfile>();
    final repo = FakeProfileRepository()..onGet = () => completer.future;
    await _pump(tester, repo);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(sampleProfile());
    await tester.pumpAndSettle();
  });

  testWidgets('error shows the API message and retry reloads', (tester) async {
    final repo = FakeProfileRepository()
      ..onGet = () async =>
          throw const ApiException(code: 'X', message: 'Máy chủ lỗi');
    await _pump(tester, repo);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('Máy chủ lỗi'), findsOneWidget);

    repo.onGet = () async => sampleProfile();
    await tester.tap(find.widgetWithText(HvpButton, 'THỬ LẠI'));
    await tester.pumpAndSettle();
    expect(repo.getCalls, 2);
  });
}
