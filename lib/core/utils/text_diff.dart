/// Small text helpers shared by widgets and services.
abstract final class TextTools {
  /// Collapses all whitespace into single spaces and trims the result.
  static String collapseWhitespace(String input) =>
      input.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Truncates [input] to [maxLength] characters, adding an ellipsis when cut.
  static String ellipsize(String input, int maxLength) {
    final trimmed = input.trim();
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength).trimRight()}…';
  }

  /// Counts *words* for Persian text, treating ZWNJ as part of a word.
  static int wordCount(String input) {
    final collapsed = collapseWhitespace(input);
    if (collapsed.isEmpty) return 0;
    return collapsed.split(' ').length;
  }
}
