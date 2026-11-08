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
