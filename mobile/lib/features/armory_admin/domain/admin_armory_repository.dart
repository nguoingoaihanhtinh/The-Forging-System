class CreateArmoryTierInput {
  const CreateArmoryTierInput({
    required this.code,
    required this.name,
    required this.minMarks,
    this.maxMarks,
    required this.sortOrder,
  });

  final String code;
  final String name;
  final int minMarks;
  final int? maxMarks;
  final int sortOrder;
}

abstract interface class AdminArmoryRepository {
  Future<void> createTier(CreateArmoryTierInput input);
}
