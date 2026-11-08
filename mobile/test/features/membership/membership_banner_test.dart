import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/core/widgets/hvp_button.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/membership/domain/membership_models.dart';
import 'package:hvp_forging/features/membership/presentation/providers/membership_providers.dart';
import 'package:hvp_forging/features/membership/presentation/widgets/membership_banner.dart';

import '../../helpers/fake_membership_repository.dart';
import '../../helpers/test_harness.dart';

Future<void> _pump(WidgetTester tester, Future<MyMembership> Function() result,
    {bool settle = true}) async {
  await pumpHvp(
    tester,
    Scaffold(
      body: MembershipBanner(onAction: () {}),
    ),
    overrides: <Override>[
      membershipRepositoryProvider
          .overrideWithValue(FakeMembershipRepository(result)),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
  if (settle) await tester.pumpAndSettle();
}

MyMembership _m(RenewNotice n, {MemberStatus s = MemberStatus.active}) =>
    MyMembership(memberStatus: s, renewNotice: n);

void main() {
  testWidgets('no plan variant with a working CTA', (tester) async {
    await _pump(tester, () async => _m(RenewNotice.noPackage));
    expect(find.text('Chào mừng! Bạn chưa có gói tập'), findsOneWidget);
    expect(find.text('ĐĂNG KÝ GÓI TẬP'), findsOneWidget);
  });

  testWidgets('frozen variant', (tester) async {
    await _pump(tester, () async => _m(RenewNotice.ok, s: MemberStatus.frozen));
    expect(
        find.text('Tài khoản đang đóng băng — chế độ chỉ xem'), findsOneWidget);
  });

  testWidgets('renders nothing when OK, loading or on error', (tester) async {
    await _pump(tester, () async => _m(RenewNotice.ok));
    expect(find.byType(HvpButton), findsNothing);
  });

  testWidgets('renders nothing while loading', (tester) async {
    final c = Completer<MyMembership>();
    await _pump(tester, () => c.future, settle: false);
    await tester.pump();
    expect(find.byType(HvpButton), findsNothing);
    c.complete(_m(RenewNotice.ok));
    await tester.pumpAndSettle();
  });

  testWidgets('renders nothing on error', (tester) async {
    await _pump(tester,
        () async => throw const ApiException(code: 'X', message: 'Lỗi'));
    expect(find.byType(HvpButton), findsNothing);
    expect(find.text('Lỗi'), findsNothing);
  });

  testWidgets('CTA calls onAction', (tester) async {
    var taps = 0;
    await pumpHvp(
      tester,
      Scaffold(body: MembershipBanner(onAction: () => taps++)),
      overrides: <Override>[
        membershipRepositoryProvider.overrideWithValue(
            FakeMembershipRepository(() async => _m(RenewNotice.ended))),
        currentUserIdProvider.overrideWithValue('u1'),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ĐĂNG KÝ GÓI MỚI'));
    expect(taps, 1);
  });
}
