class MemoryIntentRouter {
  static final RegExp _explicit = RegExp(
    r'\b(remember|recall|memory|earlier|before|previous|last time|we discussed|we talked|you know about me|my name|my preference|my address|my birthday|continue|resume|again|same as|what did i|what have i|did i tell)\b',
    caseSensitive: false,
  );

  static final RegExp _dependent = RegExp(
    r'^(continue|resume|do it|use that|change it|fix it|finish it|the same|as before)\b',
    caseSensitive: false,
  );

  static bool shouldRecall(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return false;
    return _explicit.hasMatch(normalized) || _dependent.hasMatch(normalized);
  }
}
