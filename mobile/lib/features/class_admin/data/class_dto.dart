import '../../../core/utils/json_utils.dart';
import '../domain/class_models.dart';

ClassSummary classSummaryFromJson(JsonMap j) => ClassSummary(
      id: str(j, 'id'),
      branchId: str(j, 'branchId'),
      name: str(j, 'name'),
      sessionTypeCode: str(j, 'sessionTypeCode'),
      courseId: strOrNull(j, 'courseId'),
      defaultCoachId: strOrNull(j, 'defaultCoachId'),
      weekdays: asList(j['weekdays'])
          .whereType<num>()
          .map((d) => d.toInt())
          .toList(growable: false),
      startTime: str(j, 'startTime'),
      durationMinutes: intOf(j, 'durationMinutes'),
      capacity: j['capacity'] == null ? null : intOf(j, 'capacity'),
      isActive: boolOf(j, 'isActive', true),
      enrolledCount: intOf(j, 'enrolledCount'),
    );
