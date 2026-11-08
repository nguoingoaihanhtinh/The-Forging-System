import '../../../core/network/api_client.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/course.dart';

class CourseRepositoryImpl implements CourseRepository {
  CourseRepositoryImpl(this.api);

  final ApiClient api;

  @override
  Future<List<Course>> courses() async {
    final response = await api.get('/courses');
    return response.dataList.map((entry) => _course(asMap(entry))).toList(growable: false);
  }

  @override
  Future<CourseDetail> course(String courseId) async {
    final j = (await api.get('/courses/$courseId')).dataMap;
    return CourseDetail(
      course: _course(j),
      lessons: asList(j['lessons']).map((e) => _lesson(asMap(e))).toList(growable: false),
    );
  }

  @override
  Future<Lesson> lesson(String courseId, int lessonNo) async {
    final j = (await api.get('/courses/$courseId/lessons/$lessonNo')).dataMap;
    return Lesson(
      courseId: str(j, 'courseId', courseId),
      summary: _lesson(j),
      objectives: strOrNull(j, 'objectives'),
      content: asMap(j['content']),
    );
  }

  Course _course(JsonMap j) => Course(
        id: str(j, 'id'),
        code: str(j, 'code'),
        name: str(j, 'name'),
        durationWeeks: intOf(j, 'durationWeeks'),
        totalLessons: intOf(j, 'totalLessons'),
        description: strOrNull(j, 'description'),
        progress: _progress(asMap(j['progress'])),
      );

  // Staff get `progress: null`; treat it like a course that was never started.
  CourseProgress _progress(JsonMap j) => CourseProgress(
        status: switch (str(j, 'status')) {
          'IN_PROGRESS' => CourseStatus.inProgress,
          'COMPLETED' => CourseStatus.completed,
          _ => CourseStatus.notStarted,
        },
        lessonsCompleted: intOf(j, 'lessonsCompleted'),
      );

  LessonSummary _lesson(JsonMap j) => LessonSummary(
        lessonNo: intOf(j, 'lessonNo'),
        weekNo: j['weekNo'] == null ? null : intOf(j, 'weekNo'),
        title: str(j, 'title'),
        subtitle: strOrNull(j, 'subtitle'),
        isAssessment: boolOf(j, 'isAssessment'),
        isGraduation: boolOf(j, 'isGraduation'),
        isAdvanced: boolOf(j, 'isAdvanced'),
      );
}
