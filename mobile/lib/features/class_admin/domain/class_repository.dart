import 'class_models.dart';

abstract interface class ClassRepository {
  Future<ClassPage> list(ClassQuery query);

  Future<ClassSummary> create(ClassDraft draft);

  /// [changes] holds only the edited fields (see [ClassDraft.changesFrom]).
  Future<ClassSummary> update(String id, Map<String, Object?> changes);

  /// Coaches and head coaches, for pickers and for naming a class's coach.
  Future<List<ClassCoach>> coaches();
}
