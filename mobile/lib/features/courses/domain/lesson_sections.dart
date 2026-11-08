import 'course.dart';

/// One block of the lesson screen: a title with a paragraph and/or a list.
class LessonSection {
  const LessonSection({required this.title, this.text, this.items = const <String>[], this.numbered = false});

  final String title;
  final String? text;
  final List<String> items;

  /// Steps of a session (drills) read better numbered than as bullets.
  final bool numbered;
}

const Map<String, String> _knownTitles = <String, String>{
  'drills': 'Giáo án buổi tập',
};

/// Turns a lesson into the blocks to show: the objectives, then every
/// string / list-of-strings entry of the admin-editable `content`.
/// Entries of any other shape are skipped so an odd payload never breaks the screen.
List<LessonSection> lessonSections(Lesson lesson) {
  final sections = <LessonSection>[
    if (lesson.objectives != null) LessonSection(title: 'Mục tiêu', text: lesson.objectives),
  ];
  for (final entry in lesson.content.entries) {
    final value = entry.value;
    final title = _knownTitles[entry.key] ?? _humanize(entry.key);
    if (value is String && value.trim().isNotEmpty) {
      sections.add(LessonSection(title: title, text: value.trim()));
    } else if (value is List) {
      final items = value.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
      if (items.isNotEmpty) sections.add(LessonSection(title: title, items: items, numbered: entry.key == 'drills'));
    }
  }
  return sections;
}

/// `warmUpNotes` / `warm_up_notes` -> `Warm up notes`.
String _humanize(String key) {
  final spaced = key
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .trim();
  if (spaced.isEmpty) return key;
  return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
}
