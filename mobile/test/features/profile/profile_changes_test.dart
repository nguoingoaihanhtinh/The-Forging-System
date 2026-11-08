import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/features/profile/domain/profile_changes.dart';

import 'fixtures.dart';

void main() {
  final current = sampleProfile();

  test('nothing changed -> empty body', () {
    expect(
        profileChanges(current,
            fullName: ' Nguyễn Văn A ',
            phone: '0912345678',
            email: 'a@example.com'),
        isEmpty);
  });

  test('only the changed fields are sent', () {
    expect(
      profileChanges(current,
          fullName: 'Nguyễn Văn B',
          phone: '0912345678',
          email: 'a@example.com'),
      <String, Object?>{'fullName': 'Nguyễn Văn B'},
    );
  });

  test('a blank phone or email is sent as null', () {
    expect(
      profileChanges(current, fullName: 'Nguyễn Văn A', phone: '', email: '  '),
      <String, Object?>{'phone': null, 'email': null},
    );
  });

  test('a blank field that was already empty is not sent', () {
    final noEmail = sampleProfile(email: null);
    expect(
        profileChanges(noEmail,
            fullName: 'Nguyễn Văn A', phone: '0912345678', email: ''),
        isEmpty);
  });
}
