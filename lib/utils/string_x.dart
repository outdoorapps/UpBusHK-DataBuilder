extension StringX on String {
  /// Standardize Minibus Chinese stop names
  String standardizeChiStopName() {
    String s = this;

    // 1. Remove ideographic space \u3000
    s = s.replaceAll('\u3000', '');

    // 2. Convert full-width letters/numbers/hyphen to half-width
    s = s.replaceAllMapped(
      RegExp(r'[Ａ-Ｚａ-ｚ０-９－]'),
      (m) => _toHalfWidth(m.group(0)!),
    );

    // 3. Replace Chinese-style commas with half-width comma + space
    s = s.replaceAll(RegExp(r'\s*,\s*|，'), ', ');

    // 4. Remove whitespace after 近 when followed by Han characters
    //    e.g. 近   富豪苑 → 近富豪苑
    s = s.replaceAllMapped(
      RegExp(r'近\s*\p{Script=Han}', unicode: true),
      (m) => m.group(0)!.replaceAll(RegExp(r'\s+'), ''),
    );

    // 5. Add space after 近 when followed by English (except M+博物館)
    s = s.replaceAllMapped(RegExp(r'近[A-Za-z]{3,}'), (m) {
      final full = m.group(0)!; // e.g. "近One Hennessy"
      final english = full.substring(1); // remove "近"
      if (english.startsWith("M+博物館")) return full; // exception
      return "近 $english"; // insert space
    });

    // 6. Remove whitespace between Chinese + English + Chinese
    s = s.replaceAllMapped(
      RegExp(r'\p{Script=Han}\s*[A-Za-z0-9-]+\s*\p{Script=Han}', unicode: true),
      (m) => m.group(0)!.replaceAll(RegExp(r'\s+'), ''),
    );

    // 7. Trim final whitespace
    return s.trim();
  }
}

/// Helper: convert full-width to half-width
String _toHalfWidth(String input) {
  final code = input.codeUnitAt(0);
  // Full-width A-Z or a-z or 0-9 → subtract 65248
  if (code >= 0xFF01 && code <= 0xFF5E) {
    return String.fromCharCode(code - 65248);
  }
  if (code == 0xFF0D) return '-'; // Full-width hyphen "－" (U+FF0D)

  return input;
}
