import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/armory_admin/domain/admin_armory_repository.dart';
import 'package:hvp_forging/features/armory_admin/presentation/admin_armory_providers.dart';
import 'package:hvp_forging/features/armory_admin/presentation/screens/admin_armory_tiers_screen.dart';

import '../../helpers/test_harness.dart';

class FakeAdminArmoryRepository implements AdminArmoryRepository {
  CreateArmoryTierInput? created;

  @override
  Future<void> createTier(CreateArmoryTierInput input) async {
    created = input;
  }

  @override
  Future<List<AdminArmoryTier>> tiers() async => const <AdminArmoryTier>[];

  @override
  Future<void> updateTier(String code, UpdateArmoryTierInput input) async {}

  @override
  Future<AdminArmoryRewardPage> rewards({
    String? query,
    String? tierCode,
    bool? isActive,
    int page = 1,
  }) async =>
      const AdminArmoryRewardPage(
          items: <AdminArmoryReward>[], page: 1, totalPages: 1);

  @override
  Future<AdminArmoryReward> reward(String id) => throw UnimplementedError();

  @override
  Future<void> createReward(CreateArmoryRewardInput input) async {}

  @override
  Future<void> updateReward(String id, UpdateArmoryRewardInput input) async {}
}

void main() {
  testWidgets('creates tier with nullable maximum Marks', (tester) async {
    final repository = FakeAdminArmoryRepository();
    await pumpHvp(tester, const AdminArmoryTiersScreen(), overrides: [
      adminArmoryRepositoryProvider.overrideWithValue(repository),
    ]);

    await tester.enterText(find.byType(TextFormField).at(0), 'gold');
    await tester.enterText(find.byType(TextFormField).at(1), 'Vàng');
    await tester.enterText(find.byType(TextFormField).at(2), '100');
    await tester.tap(find.text('TẠO TIER'));
    await tester.pumpAndSettle();

    expect(repository.created?.code, 'GOLD');
    expect(repository.created?.name, 'Vàng');
    expect(repository.created?.minMarks, 100);
    expect(repository.created?.maxMarks, isNull);
    expect(repository.created?.sortOrder, 0);
  });

  testWidgets('does not submit when maximum Marks is below minimum',
      (tester) async {
    final repository = FakeAdminArmoryRepository();
    await pumpHvp(tester, const AdminArmoryTiersScreen(), overrides: [
      adminArmoryRepositoryProvider.overrideWithValue(repository),
    ]);

    await tester.enterText(find.byType(TextFormField).at(0), 'GOLD');
    await tester.enterText(find.byType(TextFormField).at(1), 'Vàng');
    await tester.enterText(find.byType(TextFormField).at(2), '100');
    await tester.enterText(find.byType(TextFormField).at(3), '99');
    await tester.tap(find.text('TẠO TIER'));
    await tester.pumpAndSettle();

    expect(repository.created, isNull);
    expect(find.textContaining('Marks tối đa phải'), findsOneWidget);
  });
}
