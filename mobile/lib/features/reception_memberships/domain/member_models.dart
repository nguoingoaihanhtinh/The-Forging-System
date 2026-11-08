import '../../membership/domain/membership_models.dart';

/// The learner as the front desk sees them (`GET /members/:memberId`).
class MemberProfile {
  const MemberProfile({
    required this.id,
    required this.memberCode,
    required this.fullName,
    required this.status,
    this.phone,
    this.email,
    this.avatarUrl,
    this.statusReason,
    this.joinedAt,
    this.homeBranchName,
  });

  final String id;
  final String memberCode;
  final String fullName;

  /// `ACTIVE`, `FROZEN` or `INACTIVE`.
  final String status;
  final String? phone;
  final String? email;
  final String? avatarUrl;

  /// Why the account is frozen or inactive.
  final String? statusReason;
  final DateTime? joinedAt;
  final String? homeBranchName;
}

/// Profile plus packages: everything on the learner detail screen.
class MemberOverview {
  const MemberOverview({required this.profile, required this.membership});

  final MemberProfile profile;
  final MyMembership membership;
}

/// A learner just created at the desk; the password is shown once.
class CreatedMember {
  const CreatedMember({required this.id, this.temporaryPassword});

  final String id;
  final String? temporaryPassword;
}
