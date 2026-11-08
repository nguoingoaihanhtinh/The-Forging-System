import '../../../../core/utils/json_utils.dart';
import '../../../reception_checkin/domain/member_hit.dart';
import '../../domain/member_models.dart';

MemberProfile memberProfileFromJson(JsonMap j) => MemberProfile(
      id: str(j, 'userId'),
      memberCode: str(j, 'memberCode'),
      fullName: str(j, 'fullName'),
      status: str(j, 'status', 'ACTIVE'),
      phone: strOrNull(j, 'phone'),
      email: strOrNull(j, 'email'),
      avatarUrl: strOrNull(j, 'avatarUrl'),
      statusReason: strOrNull(j, 'statusReason'),
      joinedAt: dateOrNull(j, 'joinedAt'),
      homeBranchName: strOrNull(j, 'homeBranchName'),
    );

CreatedMember createdMemberFromJson(JsonMap j) => CreatedMember(
    id: str(j, 'userId'), temporaryPassword: strOrNull(j, 'temporaryPassword'));

MemberHit duplicateFromJson(JsonMap j) => MemberHit(
      id: str(j, 'userId'),
      memberCode: str(j, 'memberCode'),
      fullName: str(j, 'fullName'),
      phone: strOrNull(j, 'phone'),
      avatarUrl: strOrNull(j, 'avatarUrl'),
      status: str(j, 'status', 'ACTIVE'),
    );
