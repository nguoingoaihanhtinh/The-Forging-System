import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/network_providers.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../data/class_repository_impl.dart';
import '../domain/class_models.dart';
import '../domain/class_repository.dart';

final classRepositoryProvider = Provider<ClassRepository>(
    (ref) => ClassRepositoryImpl(ref.watch(apiClientProvider)));

final classPageProvider =
    FutureProvider.autoDispose.family<ClassPage, ClassQuery>((ref, query) {
  ref.watch(currentUserIdProvider);
  return ref.watch(classRepositoryProvider).list(query);
});

final classCoachesProvider =
    FutureProvider.autoDispose<List<ClassCoach>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(classRepositoryProvider).coaches();
});
