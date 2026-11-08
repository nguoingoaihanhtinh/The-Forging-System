class SessionType {
  const SessionType(this.code, this.label);

  final String code;
  final String label;
}

// ponytail: mirrors the seeded session_types; replace with an API when admins can add types.
const List<SessionType> sessionTypes = <SessionType>[
  SessionType('GROUP', 'Group Class'),
  SessionType('PT', 'PT 1:1'),
  SessionType('ACADEMY', 'Academy Lesson'),
  SessionType('WORKSHOP', 'Workshop'),
  SessionType('SPARRING', 'Sparring Day'),
];

/// Label of a session type code; unknown codes are shown as sent.
String sessionTypeLabel(String code) {
  for (final type in sessionTypes) {
    if (type.code == code) return type.label;
  }
  return code;
}
