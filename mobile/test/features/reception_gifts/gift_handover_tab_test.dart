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

final readyPage2 = StaffRedemption(
  id: 'ready-2',
  redemptionCode: 'GFT-READY-2',
  memberId: 'member-3',
  memberCode: 'HV003',
  memberFullName: 'Lê Cường',
  rewardId: 'reward-2',
  rewardName: 'Áo tập trang 2',
  rewardSku: 'SHIRT',
  pickupBranchId: 'branch-1',
  pickupBranchName: 'HVP Quận 1',
  marksCost: 150,
  status: 'READY_PICKUP',
  requestedAt: DateTime.utc(2026, 11, 3),
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
  FakeStaffRedemptions({this.twoPages = false});

  final bool twoPages;
  int approveCalls = 0;
  final deliveries =
      <({String id, String? reason, String? evidenceUrl})>[];
  final statuses = <String?>[];

  @override
  Future<StaffRedemptionPage> list(
      {String? status, String? query, int page = 1}) async {
    statuses.add(status);
    if (twoPages) {
      return StaffRedemptionPage(
        items: <StaffRedemption>[page == 1 ? ready : readyPage2],
        page: page,
        totalPages: 2,
        total: 2,
      );
    }
    return StaffRedemptionPage(
      items: status == 'PENDING_PICKUP'
          ? <StaffRedemption>[pending]
          : <StaffRedemption>[ready],
      page: page,
      totalPages: 1,
      total: 1,
    );
  }

  @override
  Future<void> approve(String redemptionId, {String? reason}) async {
    approveCalls++;
  }

  @override
  Future<void> deliver(String redemptionId,
      {String? reason, String? evidenceUrl}) async {
    deliveries.add(
        (id: redemptionId, reason: reason, evidenceUrl: evidenceUrl));
  }

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

  testWidgets('delivers a gift with an optional note and receipt photo',
      (tester) async {
    final repository = FakeStaffRedemptions();
    await pumpHvp(tester, const Scaffold(body: GiftHandoverTab()), overrides: [
      staffRedemptionRepositoryProvider.overrideWithValue(repository),
      deliveryPhotoFieldBuilderProvider.overrideWithValue(
        (context, onChanged) => TextButton(
          onPressed: () => onChanged('https://files.example/receipt.jpg'),
          child: const Text('GẮN ẢNH'),
        ),
      ),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('GIAO QUÀ'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).last, 'Đã bàn giao tại quầy');
    await tester.tap(find.text('GẮN ẢNH'));
    await tester.pump();
    await tester.tap(find.text('XÁC NHẬN ĐÃ GIAO'));
    await tester.pumpAndSettle();

    expect(repository.deliveries.single, (
      id: 'ready-1',
      reason: 'Đã bàn giao tại quầy',
      evidenceUrl: 'https://files.example/receipt.jpg',
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('paginates the queue and exposes delivered/rejected filters',
      (tester) async {
    final repository = FakeStaffRedemptions(twoPages: true);
    await pumpHvp(tester, const Scaffold(body: GiftHandoverTab()), overrides: [
      staffRedemptionRepositoryProvider.overrideWithValue(repository),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Găng tập'), findsOneWidget);
    await tester.tap(find.text('Trang sau'));
    await tester.pumpAndSettle();
    expect(find.text('Áo tập trang 2'), findsOneWidget);

    await tester.dragUntilVisible(find.text('Đã giao'),
        find.byType(ListView).first, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Đã giao'), findsOneWidget);
    await tester.tap(find.text('Đã giao'));
    await tester.pumpAndSettle();
    expect(repository.statuses.last, 'DELIVERED');

    await tester.dragUntilVisible(find.text('Từ chối'),
        find.byType(ListView).first, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.text('Từ chối'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
