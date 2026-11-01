import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/course_repository_impl.dart';
import '../domain/course.dart';

final courseRepositoryProvider =
    Provider<CourseRepository>((ref) => CourseRepositoryImpl(ref.watch(apiClientProvider)));

/// Progress is per learner, so every sign-in starts from a fresh fetch.
final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(courseRepositoryProvider).courses();
});

final courseDetailProvider = FutureProvider.autoDispose.family<CourseDetail, String>((ref, courseId) {
  ref.watch(currentUserIdProvider);
  return ref.watch(courseRepositoryProvider).course(courseId);
});

final lessonProvider =
    FutureProvider.autoDispose.family<Lesson, ({String courseId, int lessonNo})>((ref, key) {
  ref.watch(currentUserIdProvider);
  return ref.watch(courseRepositoryProvider).lesson(key.courseId, key.lessonNo);
});
