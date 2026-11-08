import 'package:hvp_forging/features/profile/domain/profile_models.dart';
import 'package:hvp_forging/features/profile/domain/profile_repository.dart';

MemberProfile sampleProfile({
  String fullName = 'Nguyễn Văn A',
  String? phone = '0912345678',
  String? email = 'a@example.com',
  String? avatarUrl,
  String status = 'ACTIVE',
}) =>
    MemberProfile(
      userId: 'user-student',
      fullName: fullName,
      phone: phone,
      email: email,
      avatarUrl: avatarUrl,
      homeBranchName: 'HVP Boxing - The Corner',
      joinedAt: DateTime.utc(2026, 10, 1, 3),
      status: status,
      currentRankId: 'r3',
    );

class FakeProfileRepository implements ProfileRepository {
  Future<MemberProfile> Function() onGet = () async => sampleProfile();

  int getCalls = 0;

  @override
  Future<MemberProfile> getProfile() {
    getCalls++;
    return onGet();
  }
}
