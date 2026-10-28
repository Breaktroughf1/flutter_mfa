/// Normalises a submitted code: removes ASCII spaces (users type `123 456`)
/// and returns `null` unless what is left is exactly [digits] ASCII digits
/// (FR-VER-06). Unicode digits such as `٣` are rejected.
String? normalizeCode(String input, int digits) {
  final code = input.replaceAll(' ', '');
  if (code.length != digits) return null;
  for (var i = 0; i < code.length; i++) {
    final c = code.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) return null;
  }
  return code;
}
