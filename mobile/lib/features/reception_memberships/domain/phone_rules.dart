/// Local form of a Vietnamese phone number, as the backend stores it: `+84 912 345 678` -> `0912345678`.
String normalizePhone(String value) {
  final compact = value.replaceAll(RegExp(r'[\s.-]'), '');
  return compact.startsWith('+84') ? '0${compact.substring(3)}' : compact;
}

bool samePhone(String? a, String? b) =>
    a != null && b != null && normalizePhone(a) == normalizePhone(b);
