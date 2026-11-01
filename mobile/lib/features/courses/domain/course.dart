/// How far a learner is in a course (the backend sends it as `progress`).
enum CourseStatus { notStarted, inProgress, completed }

class CourseProgress {
  const CourseProgress({required this.status, required this.lessonsCompleted});

  final CourseStatus status;
  final int lessonsCompleted;
}

class Course {
  const Course({
    required this.id,
    required this.code,
    required this.name,
    required this.durationWeeks,
    required this.totalLessons,
    required this.progress,
    this.description,
  });

  final String id;
  final String code;
  final String name;
  final int durationWeeks;
  final int totalLessons;
  final String? description;
  final CourseProgress progress;

  /// 0..1 share of lessons done; 0 for a course without lessons.
  double get progressRatio =>
      totalLessons <= 0 ? 0 : (progress.lessonsCompleted / totalLessons).clamp(0.0, 1.0);
}

class LessonSummary {
  const LessonSummary({
    required this.lessonNo,
    required this.title,
    required this.isAssessment,
    required this.isGraduation,
    required this.isAdvanced,
    this.weekNo,
    this.subtitle,
  });

  final int lessonNo;
  final int? weekNo;
  final String title;
  final String? subtitle;
  final bool isAssessment;
  final bool isGraduation;
  final bool isAdvanced;
}

class CourseDetail {
  const CourseDetail({required this.course, required this.lessons});

  final Course course;
  final List<LessonSummary> lessons;

  /// Lessons grouped by week, in week order; lessons without a week go last under key 0.
  Map<int, List<LessonSummary>> get lessonsByWeek {
    final groups = <int, List<LessonSummary>>{};
    for (final lesson in lessons) {
      groups.putIfAbsent(lesson.weekNo ?? 0, () => <LessonSummary>[]).add(lesson);
    }
    final weeks = groups.keys.toList()
      ..sort((a, b) => a == 0 ? 1 : (b == 0 ? -1 : a.compareTo(b)));
    return <int, List<LessonSummary>>{for (final w in weeks) w: groups[w]!};
  }
}

abstract interface class CourseRepository {
  /// Active courses in curriculum order (BOOK I..V).
  Future<List<Course>> courses();

  Future<CourseDetail> course(String courseId);
}
