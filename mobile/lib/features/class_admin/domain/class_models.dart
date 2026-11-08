/// A class as listed (`ClassRow` + `enrolledCount`).
class ClassSummary {
  const ClassSummary({
    required this.id,
    required this.branchId,
    required this.name,
    required this.sessionTypeCode,
    required this.weekdays,
    required this.startTime,
    required this.durationMinutes,
    required this.isActive,
    required this.enrolledCount,
    this.courseId,
    this.defaultCoachId,
    this.capacity,
  });

  final String id;
  final String branchId;
  final String name;
  final String sessionTypeCode;
  final String? courseId;
  final String? defaultCoachId;

  /// ISO weekdays, 1 = Monday ... 7 = Sunday.
  final List<int> weekdays;

  /// `HH:mm`, local time.
  final String startTime;
  final int durationMinutes;

  /// Null = no limit.
  final int? capacity;
  final bool isActive;
  final int enrolledCount;
}

class ClassQuery {
  const ClassQuery({this.sessionTypeCode, this.page = 1, this.limit = 20});

  final String? sessionTypeCode;
  final int page;
  final int limit;

  @override
  bool operator ==(Object other) =>
      other is ClassQuery &&
      other.sessionTypeCode == sessionTypeCode &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(sessionTypeCode, page, limit);
}

class ClassPage {
  const ClassPage(
      {required this.items,
      required this.page,
      required this.total,
      required this.totalPages});

  final List<ClassSummary> items;
  final int page;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// A staff member who can lead a class.
class ClassCoach {
  const ClassCoach(this.id, this.name);

  final String id;
  final String name;
}

/// Fields of the create/edit form (CLS-07).
class ClassDraft {
  const ClassDraft({
    required this.branchId,
    required this.name,
    required this.sessionTypeCode,
    required this.weekdays,
    required this.startTime,
    required this.durationMinutes,
    required this.isActive,
    this.courseId,
    this.defaultCoachId,
    this.capacity,
  });

  factory ClassDraft.of(ClassSummary c) => ClassDraft(
        branchId: c.branchId,
        name: c.name,
        sessionTypeCode: c.sessionTypeCode,
        courseId: c.courseId,
        defaultCoachId: c.defaultCoachId,
        weekdays: List<int>.of(c.weekdays)..sort(),
        startTime: c.startTime,
        durationMinutes: c.durationMinutes,
        capacity: c.capacity,
        isActive: c.isActive,
      );

  final String branchId;
  final String name;
  final String sessionTypeCode;
  final String? courseId;
  final String? defaultCoachId;
  final List<int> weekdays;
  final String startTime;
  final int durationMinutes;
  final int? capacity;
  final bool isActive;

  /// Request body of `POST /admin/classes`.
  Map<String, Object?> toJson() => <String, Object?>{
        'branchId': branchId,
        'name': name.trim(),
        'sessionTypeCode': sessionTypeCode,
        'courseId': courseId,
        'defaultCoachId': defaultCoachId,
        'weekdays': weekdays,
        'startTime': startTime,
        'durationMinutes': durationMinutes,
        'capacity': capacity,
        'isActive': isActive,
      };

  /// Only the fields that differ from [before], for `PATCH /admin/classes/:id`
  /// (the API re-validates just what changed). Empty when nothing changed.
  Map<String, Object?> changesFrom(ClassDraft before) {
    final now = toJson();
    final old = before.toJson();
    return <String, Object?>{
      for (final key in now.keys)
        if (key == 'weekdays'
            ? now[key].toString() != old[key].toString()
            : now[key] != old[key])
          key: now[key],
    };
  }
}

class RosterEntry {
  const RosterEntry(
      {required this.enrollmentId,
      required this.memberId,
      required this.memberCode,
      required this.fullName});

  final String enrollmentId;
  final String memberId;
  final String memberCode;
  final String fullName;
}

class ClassDetail {
  const ClassDetail({required this.summary, required this.roster});

  final ClassSummary summary;
  final List<RosterEntry> roster;
}

class ClassSession {
  const ClassSession({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.status,
    required this.isExam,
    required this.attendeeCount,
    this.coachName,
  });

  final String id;
  final String title;
  final DateTime startsAt;

  /// `SCHEDULED`, `IN_PROGRESS`, `COMPLETED` or `CANCELLED`.
  final String status;
  final bool isExam;
  final int attendeeCount;
  final String? coachName;
}
