import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/branch_admin/presentation/screens/admin_settings_page.dart';

import '../../helpers/test_harness.dart';

void main() {
  testWidgets('CFG-04 renders configuration tabs and changes the active group',
      (tester) async {
    await pumpHvp(tester, const AdminSettingsPage());

    expect(find.text('CẤU HÌNH HỆ THỐNG'), findsOneWidget);
    expect(find.text('Chi nhánh'), findsOneWidget);
    expect(find.text('Điểm & hạng'), findsOneWidget);

    await tester.tap(find.text('Điểm & hạng'));
    await tester.pumpAndSettle();

    expect(find.text('ĐIỂM VÀ HẠNG'), findsOneWidget);
    expect(find.textContaining('DP, Marks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
