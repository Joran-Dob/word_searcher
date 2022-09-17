// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:word_searcher/word_searcher.dart';

void main() {
  group('WordSearcher', () {
    test('can be instantiated', () {
      expect(
          WordSearcher(
            onPuzzleCompleted: () {},
            words: [
              'Bhumi',
              'Cobra',
              'Compassion',
              'Dance',
              'Flute',
              'Gratitude',
              'Money',
              'Rajah',
              'Surprise',
              'Wages',
            ],
          ),
          isNotNull);
    });
  });
}
