import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/reception_gifts/domain/staff_redemption.dart';
import 'package:hvp_forging/features/reception_gifts/presentation/gift_handover_tab.dart';
import 'package:hvp_forging/features/reception_gifts/presentation/staff_redemption_providers.dart';

import '../../helpers/test_harness.dart';

final ready = StaffRedemption(
  id: 'ready-1',
  redemptionCode: 'GFT-READY',
  memberId: 'member-1',
  memberCode: 'HV001',
  memberFullName: 'Nguyễn An',
  rewardId: 'reward-1',
  rewardName: 'Găng tập',
  rewardSku: 'GLOVES',
  pickupBranchId: 'branch-1',
  pickupBranchName: 'HVP Quận 1',
  marksCost: 200,
  status: 'READY_PICKUP',
  requestedAt: DateTime.utc(2026, 11, 1),
);

final pending = StaffRedemption(
  id: 'pending-1',
  redemptionCode: 'GFT-PENDING',
  memberId: 'member-2',
  memberCode: 'HV002',
  memberFullName: 'Trần Bình',
  rewardId: 'reward-2',
  rewardName: 'Áo tập',
  rewardSku: 'SHIRT',
  pickupBranchId: 'branch-1',
  pickupBranchName: 'HVP Quận 1',
  marksCost: 150,
  status: 'PENDING_PICKUP',
  requestedAt: DateTime.utc(2026, 11, 2),
);

class FakeStaffRedemptions implements StaffRedemptionRepository {
  int approveCalls = 0;

  @override
  Future<StaffRedemptionPage> list(
          {String? status, String? query, int page = 1}) async =>
      StaffRedemptionPage(
        items: status == 'PENDING_PICKUP'
            ? <StaffRedemption>[pending]
            : <StaffRedemption>[ready],
        page: page,
        totalPages: 1,
        total: 1,
      );

  @override
  Future<void> approve(String redemptionId, {String? reason}) async {
    approveCalls++;
  }

  @override
  Future<void> deliver(String redemptionId,
      {String? reason, String? evidenceUrl}) async {}

  @override
  Future<void> reject(String redemptionId, {required String reason}) async {}
}

void main() {
  testWidgets('shows ready gifts and lets reception approve a pending gift',
      (tester) async {
    final repository = FakeStaffRedemptions();
    await pumpHvp(tester, const Scaffold(body: GiftHandoverTab()), overrides: [
      staffRedemptionRepositoryProvider.overrideWithValue(repository),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Găng tập'), findsOneWidget);
    expect(find.text('GIAO QUÀ'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(-240, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ChoiceChip).last);
    await tester.pumpAndSettle();
    expect(find.text('Áo tập'), findsOneWidget);
    await tester.tap(find.text('DUYỆT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DUYỆT ĐƠN'));
    await tester.pumpAndSettle();

    expect(repository.approveCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
