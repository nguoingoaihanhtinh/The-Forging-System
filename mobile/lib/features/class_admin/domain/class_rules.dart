const List<String> _weekdayShort = <String>[
  'T2',
  'T3',
  'T4',
  'T5',
  'T6',
  'T7',
  'CN'
];

/// `[1, 3, 5]` -> `T2, T4, T6`.
String weekdaysLabel(List<int> weekdays) {
  final sorted = List<int>.of(weekdays)..sort();
  return sorted
      .where((d) => d >= 1 && d <= 7)
      .map((d) => _weekdayShort[d - 1])
      .join(', ');
}

/// `12/20`, or `12/∞` when the class has no limit.
String enrolmentLabel(int enrolled, int? capacity) =>
    '$enrolled/${capacity ?? '∞'}';
