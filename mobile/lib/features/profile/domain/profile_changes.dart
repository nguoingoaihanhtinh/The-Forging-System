import 'profile_models.dart';

/// Builds the `PATCH /me/profile` body with only the fields that differ from
/// [current]. A blank phone or email becomes null (clears the value).
Map<String, Object?> profileChanges(
  MemberProfile current, {
  required String fullName,
  required String phone,
  required String email,
}) {
  String? orNull(String v) => v.trim().isEmpty ? null : v.trim();
  final changes = <String, Object?>{};
  if (fullName.trim() != current.fullName) {
    changes['fullName'] = fullName.trim();
  }
  if (orNull(phone) != current.phone) {
    changes['phone'] = orNull(phone);
  }
  if (orNull(email) != current.email) {
    changes['email'] = orNull(email);
  }
  return changes;
}
