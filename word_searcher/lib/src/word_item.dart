import 'package:flutter/material.dart';

class WordItem {
  WordItem({
    required this.word,
    this.found = false,
    this.foundChipColor = Colors.greenAccent,
  });

  final String word;
  final bool found;
  final Color foundChipColor;

  WordItem copyWith({
    String? word,
    bool? found,
    Color? foundChipColor,
  }) {
    return WordItem(
      word: word ?? this.word,
      found: found ?? this.found,
      foundChipColor: foundChipColor ?? this.foundChipColor,
    );
  }
}
