import 'class_models.dart';

abstract interface class ClassRepository {
  Future<ClassPage> list(ClassQuery query);

  /// Coaches and head coaches, for pickers and for naming a class's coach.
  Future<List<ClassCoach>> coaches();
}
