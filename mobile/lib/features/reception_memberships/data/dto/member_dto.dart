import '../../../../core/utils/json_utils.dart';
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
