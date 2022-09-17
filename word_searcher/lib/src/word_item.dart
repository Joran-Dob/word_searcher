class WordItem {
  WordItem({
    required this.word,
    this.found = false,
  });

  final String word;
  final bool found;

  WordItem copyWith({
    String? word,
    bool? found,
  }) {
    return WordItem(
      word: word ?? this.word,
      found: found ?? this.found,
    );
  }
}
