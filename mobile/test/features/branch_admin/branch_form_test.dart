import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/branch/branch.dart';
import 'package:hvp_forging/core/error/api_exception.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_admin_repository.dart';
import 'package:hvp_forging/features/branch_admin/domain/branch_input.dart';
import 'package:hvp_forging/features/branch_admin/presentation/providers/branch_admin_providers.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/branch_list_screen.dart';

import '../../helpers/test_harness.dart';

class _Repo implements BranchAdminRepository {
  List<Branch> branches = <Branch>[
    const Branch(id: 'b1', code: 'Q1', name: 'The Corner', latitude: 10.5),
  ];
  int listCalls = 0;
  BranchInput? created;
  (String, BranchInput)? updated;
  ApiException? failWith;

  @override
  Future<List<Branch>> getBranches() async {
    listCalls++;
    return branches;
  }

  @override
  Future<Branch> create(BranchInput input) async {
    if (failWith != null) throw failWith!;
    created = input;
    branches = <Branch>[
      ...branches,
      Branch(id: 'b2', code: input.code, name: input.name)
    ];
    return branches.last;
  }

  @override
  Future<Branch> update(String id, BranchInput input) async {
    if (failWith != null) throw failWith!;
    updated = (id, input);
    return branches.first;
  }
}

Future<void> _pump(WidgetTester tester, _Repo repo) async {
  await pumpHvp(tester, const BranchListScreen(), overrides: <Override>[
    branchAdminRepositoryProvider.overrideWithValue(repo),
    currentUserIdProvider.overrideWithValue('admin-1'),
  ]);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('add: validates, uppercases the code, saves and refreshes',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Thêm chi nhánh'));
    await tester.pumpAndSettle();
    // radius defaults to 100
    expect(find.text('100'), findsOneWidget);

    await tester.tap(find.text('TẠO CHI NHÁNH'));
    await tester.pumpAndSettle();
    expect(repo.created, isNull);
    expect(find.text('Mã gồm 2–20 ký tự: chữ, số, _ hoặc -.'), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'q7');
    await tester.enterText(fields.at(1), 'Quận 7');
    await tester.enterText(fields.at(4), '10.7');
    await tester.tap(find.text('TẠO CHI NHÁNH'));
    await tester.pumpAndSettle();

    expect(repo.created!.code, 'Q7');
    expect(repo.created!.name, 'Quận 7');
    expect(repo.created!.latitude, 10.7);
    expect(repo.created!.geofenceRadiusM, 100);
    expect(repo.listCalls, 2);
    expect(find.text('Quận 7'), findsOneWidget);
    expect(find.text('Đã tạo chi nhánh'), findsOneWidget);
  });

  testWidgets('edit: tapping a card pre-fills the form and saves a patch',
      (tester) async {
    final repo = _Repo();
    await _pump(tester, repo);

    await tester.tap(find.text('The Corner'));
    await tester.pumpAndSettle();
    expect(find.text('SỬA CHI NHÁNH'), findsOneWidget);
    expect(find.text('10.5'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'Corner 2');
    await tester.tap(find.text('LƯU THAY ĐỔI'));
    await tester.pumpAndSettle();

    expect(repo.updated!.$1, 'b1');
    expect(repo.updated!.$2.name, 'Corner 2');
    expect(find.text('Đã lưu thay đổi'), findsOneWidget);
  });

  testWidgets('taken code shows under the code field and keeps the form open',
      (tester) async {
    final repo = _Repo()
      ..failWith = const ApiException(
          code: 'BRANCH_CODE_TAKEN',
          message: 'Mã chi nhánh đã tồn tại',
          statusCode: 409);
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('Thêm chi nhánh'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Q1');
    await tester.enterText(fields.at(1), 'Dup');
    await tester.tap(find.text('TẠO CHI NHÁNH'));
    await tester.pumpAndSettle();

    expect(find.text('Mã chi nhánh đã tồn tại'), findsOneWidget);
    expect(find.text('THÊM CHI NHÁNH'), findsWidgets);
    expect(repo.listCalls, 1);
  });
}
