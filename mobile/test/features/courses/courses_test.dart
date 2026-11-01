import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hvp_forging/core/config/app_config.dart';
import 'package:hvp_forging/core/network/api_client.dart';
import 'package:hvp_forging/core/network/dio_factory.dart';
import 'package:hvp_forging/core/storage/token_store.dart';
import 'package:hvp_forging/features/auth/presentation/providers/auth_controller.dart';
import 'package:hvp_forging/features/courses/data/course_repository_impl.dart';
import 'package:hvp_forging/features/courses/domain/course.dart';
import 'package:hvp_forging/features/courses/presentation/course_detail_screen.dart';
import 'package:hvp_forging/features/courses/presentation/course_providers.dart';
import 'package:hvp_forging/features/courses/presentation/courses_screen.dart';

import '../../helpers/scripted_adapter.dart';
import '../../helpers/test_harness.dart';

const _foundation = Course(
  id: 'c1',
  code: 'FOUNDATION',
  name: 'FOUNDATION',
  durationWeeks: 12,
  totalLessons: 36,
  description: 'Nền tảng bộ pháp.',
  progress: CourseProgress(status: CourseStatus.inProgress, lessonsCompleted: 2),
);
const _standard = Course(
  id: 'c2',
  code: 'THE_STANDARD',
  name: 'THE STANDARD',
  durationWeeks: 12,
  totalLessons: 36,
  progress: CourseProgress(status: CourseStatus.notStarted, lessonsCompleted: 0),
);

class FakeCourses implements CourseRepository {
  @override
  Future<List<Course>> courses() async => const <Course>[_foundation, _standard];

  @override
  Future<CourseDetail> course(String courseId) async => const CourseDetail(
        course: _foundation,
        lessons: <LessonSummary>[
          LessonSummary(lessonNo: 1, weekNo: 1, title: 'JAB (1)', isAssessment: false, isGraduation: false, isAdvanced: false),
          LessonSummary(lessonNo: 2, weekNo: 1, title: 'CROSS (1)', isAssessment: false, isGraduation: false, isAdvanced: false),
          LessonSummary(
              lessonNo: 3, weekNo: 1, title: 'COMBO 1-2', subtitle: 'Kiểm tra tuần', isAssessment: true, isGraduation: false, isAdvanced: false),
          LessonSummary(lessonNo: 4, weekNo: 2, title: 'HOOK (1)', isAssessment: false, isGraduation: false, isAdvanced: true),
        ],
      );
}

void main() {
  test('CAT-03 repository maps courses, progress and lessons from the API', () async {
    final dio = createApiDio(
      config: const AppConfig(apiBaseUrl: 'http://test.local/api/v1', tenantCode: 'hvp'),
      tokens: MemoryTokenStore(const StoredTokens(accessToken: 'member-token', refreshToken: 'refresh')),
    );
    final adapter = ScriptedAdapter((request) {
      if (request.path == '/courses') {
        return okEnvelope(<dynamic>[
          <String, dynamic>{
            'id': 'c1',
            'code': 'FOUNDATION',
            'name': 'FOUNDATION',
            'durationWeeks': 12,
            'totalLessons': 36,
            'description': 'Nền tảng',
            'progress': <String, dynamic>{'status': 'IN_PROGRESS', 'lessonsCompleted': 7},
          },
          // Staff accounts get no progress block.
          <String, dynamic>{'id': 'c2', 'code': 'X', 'name': 'X', 'durationWeeks': 12, 'totalLessons': 36, 'progress': null},
        ]);
      }
      return okEnvelope(<String, dynamic>{
        'id': 'c1',
        'code': 'FOUNDATION',
        'name': 'FOUNDATION',
        'durationWeeks': 12,
        'totalLessons': 36,
        'progress': <String, dynamic>{'status': 'COMPLETED', 'lessonsCompleted': 36},
        'lessons': <dynamic>[
          <String, dynamic>{
            'lessonNo': 1,
            'weekNo': 1,
            'title': 'JAB (1)',
            'subtitle': null,
            'isAssessment': false,
            'isGraduation': false,
            'isAdvanced': true,
          },
        ],
      });
    });
    dio.httpClientAdapter = adapter;
    final repo = CourseRepositoryImpl(ApiClient(dio));

    final list = await repo.courses();
    expect(adapter.requests.last.path, '/courses');
    expect(list.first.progress.status, CourseStatus.inProgress);
    expect(list.first.progress.lessonsCompleted, 7);
    expect(list.first.progressRatio, closeTo(7 / 36, 1e-9));
    expect(list.last.progress.status, CourseStatus.notStarted);

    final detail = await repo.course('c1');
    expect(adapter.requests.last.path, '/courses/c1');
    expect(detail.course.progress.status, CourseStatus.completed);
    expect(detail.lessons.single, isA<LessonSummary>().having((l) => l.isAdvanced, 'isAdvanced', true));
  });

  test('lessons are grouped by week in order, week-less lessons last', () {
    const lesson = LessonSummary(lessonNo: 1, title: 't', isAssessment: false, isGraduation: false, isAdvanced: false);
    const detail = CourseDetail(
      course: _foundation,
      lessons: <LessonSummary>[
        LessonSummary(lessonNo: 9, weekNo: 3, title: 'c', isAssessment: false, isGraduation: false, isAdvanced: false),
        lesson,
        LessonSummary(lessonNo: 2, weekNo: 1, title: 'a', isAssessment: false, isGraduation: false, isAdvanced: false),
      ],
    );
    expect(detail.lessonsByWeek.keys.toList(), <int>[1, 3, 0]);
  });

  testWidgets('roadmap lists the courses in order with progress and status', (tester) async {
    await pumpHvp(tester, const CoursesScreen(), overrides: [
      currentUserIdProvider.overrideWithValue('member'),
      courseRepositoryProvider.overrideWithValue(FakeCourses()),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('FOUNDATION'), findsOneWidget);
    expect(find.text('THE STANDARD'), findsOneWidget);
    expect(find.text('2 / 36 bài'), findsOneWidget);
    expect(find.text('ĐANG HỌC'), findsOneWidget);
    expect(find.text('CHƯA BẮT ĐẦU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course detail shows lessons by week and marks done / next / special', (tester) async {
    await pumpHvp(tester, const CourseDetailScreen(courseId: 'c1'), overrides: [
      currentUserIdProvider.overrideWithValue('member'),
      courseRepositoryProvider.overrideWithValue(FakeCourses()),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('TUẦN 1'), findsOneWidget);
    expect(find.text('TUẦN 2'), findsOneWidget);
    expect(find.text('JAB (1)'), findsOneWidget);
    // 2 lessons done, so lesson 3 is next and is also the assessment.
    expect(find.text('TIẾP THEO'), findsOneWidget);
    expect(find.text('KIỂM TRA'), findsOneWidget);
    expect(find.text('NÂNG CAO'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
