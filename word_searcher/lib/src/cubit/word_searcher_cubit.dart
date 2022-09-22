import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:word_searcher/src/check_orientations.dart';
import 'package:word_searcher/src/orientations.dart';
import 'package:word_searcher/src/skip_orientations.dart';
import 'package:word_searcher/src/utils.dart';
import 'package:word_searcher/src/word_item.dart';

part 'word_searcher_state.dart';

class WordSearcherCubit extends Cubit<WordSearcherState> {
  WordSearcherCubit({
    required VoidCallback onPuzzleCompleted,
    required List<String> words,
  })  : _onPuzzleCompleted = onPuzzleCompleted,
        _words = words,
        super(WordSearcherInitial()) {
    _init();
  }

  final VoidCallback _onPuzzleCompleted;

  final List<String> _words;
  final int _width = 10;
  final int _height = 10;

  double? _puzzleItemWidth;
  double? _puzzleItemHeight;

  /// The definition of the orientation, calculates the next square given a
  /// starting square (x,y) and distance (i) from that square.
  final orientations = wsOrientations;

  /// Determines if an orientation is possible given the starting square (x,y),
  /// the height (h) and width (w) of the puzzle, and the length of the word (l).
  /// Returns true if the word will fit starting at the square provided using
  /// the specified orientation.
  final _checkOrientations = wsCheckOrientations;

  /// Determines the next possible valid square given the square (x,y) was ]
  /// invalid and a word length of (l).  This greatly reduces the number of
  /// squares that must be checked. Returning {x: x+1, y: y} will always work
  /// but will not be optimal.
  final _skipOrientations = wsSkipOrientations;

  /// Words not placed in the puzzle
  List<String> _wordsNotPlaced = [];

  /// The puzzle
  WSNewPuzzle? _puzzle;

  /// The list of valid positions for each word
  final _validWordListPositions = <String, List<Offset>>{};

  /// The list of valid positions for each word
  final _validWordPositions = <String, List<Offset>>{};

  /// Found words
  final _foundWords = <String>[];

  /// Word Items
  final _wordItems = <WordItem>[];

  void _init() {
    emit(
      WordSearcherLoading(),
    );
    _puzzle = newPuzzle(
      _words,
      WSSettings(
        height: _height,
        width: _width,
      ),
    );
    emit(
      WordSearcherLoaded(puzzle: _puzzle!, words: _wordItems),
    );
  }

  /// Initializes the puzzle and places words in the puzzle one at a time.
  ///
  /// Returns either a valid puzzle with all of the words or null if a valid
  /// puzzle was not found.
  List<List<String>>? _fillPuzzle(
    /// The list of words to fit into the puzzle
    List<String> words,

    /// The options to use when filling the puzzle
    WSSettings options,
  ) {
    final puzzle = <List<String>>[];
    // initialize the puzzle with blanks
    for (var i = 0; i < options.height; i++) {
      puzzle.add([]);
      for (var j = 0; j < options.width; j++) {
        puzzle[i].add('');
      }
    }
    // add each word into the puzzle one at a time
    for (var i = 0; i < words.length; i++) {
      if (!_placeWordInPuzzle(puzzle, options, words[i])) {
        // if a word didn't fit in the puzzle, give up
        _wordsNotPlaced.add(words[i]);
        return null;
      } else {
        _wordItems.add(WordItem(word: words[i]));
      }
    }
    // return the puzzle
    return puzzle;
  }

  /// Adds the specified word to the puzzle by finding all of the possible
  /// locations where the word will fit and then randomly selecting one. Options
  /// controls whether or not word overlap should be maximized.
  ///
  /// Returns `true` if the word was successfully placed, `false` otherwise.
  bool _placeWordInPuzzle(
    /// The current state of the puzzle
    List<List<String>> puzzle,

    /// The options to use when filling the puzzle
    WSSettings options,

    /// The word to fit into the puzzle
    String word,
  ) {
    // find all of the best locations where this word would fit
    final locations = _findBestLocations(puzzle, options, word);

    if (locations.isEmpty) {
      return false;
    }

    // select a location at random and place the word there
    final sel = locations[Random().nextInt(locations.length)];
    if (orientations[sel.orientation] == null) {
      return false;
    }

    _placeWord(
      puzzle,
      word,
      sel.x,
      sel.y,
      orientations[sel.orientation]!,
    );
    return true;
  }

  /// Iterates through the puzzle and determines all of the locations where
  /// the word will fit. Options determines if overlap should be maximized or
  /// not.
  ///
  /// Returns a list of location objects which contain an x,y cooridinate
  /// indicating the start of the word, the orientation of the word, and the
  /// number of letters that overlapped with existing letter.
  List<WSLocation> _findBestLocations(
    /// The current state of the puzzle
    List<List<String>> puzzle,

    /// The options to use when filling the puzzle
    WSSettings options,

    /// The word to fit into the puzzle
    String word,
  ) {
    final locations = <WSLocation>[];
    final height = options.height;
    final width = options.width;
    final wordLength = word.length;
    // we'll start looking at overlap = 0
    var maxOverlap = 0;

    // loop through all of the possible orientations at this position
    for (var i = 0; i < options.orientations.length; i++) {
      final orientation = options.orientations[i];
      final next = orientations[orientation]!;
      final check = _checkOrientations[orientation]!;
      final skip = _skipOrientations[orientation]!;
      var x = 0;
      var y = 0;
      // loop through every position on the board
      while (y < height) {
        // see if this orientation is even possible at this location
        if (check(x, y, height, width, wordLength)) {
          // determine if the word fits at the current position
          final overlap = _calcOverlap(word, puzzle, x, y, next);
          // if the overlap was bigger than previous overlaps that we've seen
          if (overlap >= maxOverlap || (!options.preferOverlap && overlap > -1)) {
            maxOverlap = overlap;
            locations.add(
              WSLocation(
                x: x,
                y: y,
                orientation: orientation,
                overlap: overlap,
                word: word,
              ),
            );
          }
          // increment x position
          x += 1;
          if (x >= width) {
            x = 0;
            // increment y position
            y += 1;
          }
        } else {
          // if current cell is invalid, then skip to the next cell where
          // this orientation is possible. this greatly reduces the number
          // of checks that we have to do overall
          final nextPossible = skip(x, y, wordLength);
          x = nextPossible.x;
          y = nextPossible.y;
        }
      }
    }

    // finally prune down all of the possible locations we found by
    // only using the ones with the maximum overlap that we calculated
    return options.preferOverlap ? _pruneLocations(locations, maxOverlap) : locations;
  }

  /// Determines whether or not a particular word fits in a particular
  /// orientation within the puzzle.
  ///
  /// Returns the number of letters overlapped with existing words if the word
  /// fits in the specified position, -1 if the word does not fit.
  int _calcOverlap(
    /// The word to fit into the puzzle
    String word,

    /// The current state of the puzzle
    List<List<String>> puzzle,

    /// The x position to check
    int x,

    /// The y position to check
    int y,

    /// Function that returns the next square
    WSOrientationFn fnGetSquare,
  ) {
    var overlap = 0;

    // traverse the squares to determine if the word fits
    for (var i = 0; i < word.length; i++) {
      final next = fnGetSquare(x, y, i);
      String? square;
      try {
        square = puzzle[next.y][next.x];
      } catch (_e) {
        square = null;
      }
      // if the puzzle square already contains the letter we
      // are looking for, then count it as an overlap square
      if (square == word[i]) {
        overlap++;
      }
      // if it contains a different letter, than our word doesn't fit
      // here, return -1
      else if (square != '') {
        return -1;
      }
    }

    // if the entire word is overlapping, skip it to ensure words aren't
    // hidden in other words
    return overlap;
  }

  /// If overlap maximization was indicated, this function is used to prune the
  /// list of valid locations down to the ones that contain the maximum overlap
  /// that was previously calculated.
  ///
  /// Returns the pruned set of locations.
  List<WSLocation> _pruneLocations(
    /// The set of locations to prune
    List<WSLocation> locations,

    /// The required level of overlap
    int overlap,
  ) {
    final pruned = <WSLocation>[];
    for (var i = 0; i < locations.length; i++) {
      if (locations[i].overlap >= overlap) {
        pruned.add(locations[i]);
      }
    }
    return pruned;
  }

  /// Places a word in the puzzle given a starting position and orientation.
  void _placeWord(
    /// The current state of the puzzle
    List<List<String>> puzzle,

    ///  The word to fit into the puzzle
    String word,

    /// The x position to check
    int x,

    /// The y position to check
    int y,

    /// Function that returns the next square
    WSOrientationFn fnGetSquare,
  ) {
    final wordPositions = <Offset>[];
    for (var i = 0; i < word.length; i++) {
      final next = fnGetSquare(x, y, i);
      try {
        puzzle[next.y][next.x] = word[i];
        if (i == 0 || i == word.length - 1) {
          wordPositions.add(Offset(next.x.toDouble(), next.y.toDouble()));
        }
      } catch (e) {
        debugPrint(e.toString());
        debugPrint(e.toString());
      }
    }
    _validWordListPositions[word] = wordPositions;
  }

  /// Fills in any empty spaces in the puzzle with random letters.
  int _fillBlanks(
    /// The current state of the puzzle
    List<List<String>> puzzle,

    /// Function to add extra letters to fill blanks
    String Function() extraLetterGenerator,
  ) {
    var extraLettersCount = 0;
    for (var i = 0, height = puzzle.length; i < height; i++) {
      final row = puzzle[i];
      for (var j = 0, width = row.length; j < width; j++) {
        if (puzzle[i][j] == '') {
          puzzle[i][j] = extraLetterGenerator();
          extraLettersCount += 1;
        }
      }
    }
    return extraLettersCount;
  }

  /// Generates a new word find (word search) puzzle.
  ///
  /// Example:
  /// ```
  /// final List<String> wl = ['hello', 'world', 'foo', 'bar', 'baz', 'dart'];
  /// final WSSettings ws = WSSettings();
  /// final WordSearch wordSearch = WordSearch();
  /// final WSNewPuzzle newPuzzle = wordSearch.newPuzzle(wl, ws);
  /// debugPrint(newPuzzle.puzzle);
  /// ```
  ///
  WSNewPuzzle newPuzzle(
    /// The words to be placed in the puzzle
    List<String> words,

    /// The puzzle setting object
    WSSettings settings,
  ) {
    // New instance of the output data
    final output = WSNewPuzzle();
    if (words.isEmpty) {
      output.errors.add('Zero words provided');
      return output;
    }
    List<List<String>>? puzzle;
    var attempts = 0;
    var gridGrowths = 0;

    // copy and sort the words by length, inserting words into the puzzle
    // from longest to shortest works out the best
    final wordList = <String>[]
      ..addAll(words)
      ..sort((String a, String b) {
        return b.length - a.length;
      });
    // max word length
    final maxWordLength = wordList.first.length;
    // create new options instance of the settings
    final options = WSSettings(
      width: settings.width != null ? settings.width : maxWordLength,
      height: settings.height != null ? settings.height : maxWordLength,
      orientations: settings.orientations,
      fillBlanks: settings.fillBlanks ?? true,
      maxAttempts: settings.maxAttempts,
      maxGridGrowth: settings.maxGridGrowth,
      preferOverlap: settings.preferOverlap,
      allowExtraBlanks: settings.allowExtraBlanks,
    );
    while (puzzle == null) {
      while (puzzle == null && attempts++ < options.maxAttempts) {
        _wordsNotPlaced = [];
        puzzle = _fillPuzzle(wordList, options);
      }
      if (puzzle == null) {
        // Increase the size of the grid
        gridGrowths += 1;
        // No more grid growths allowed
        if (gridGrowths > options.maxGridGrowth) {
          output.errors.add(
            'No valid ${options.width}x${options.height} grid found and not allowed to grow more',
          );
          return output;
        }
        debugPrint('Trying a bigger grid after ${attempts - 1}');
        options.height += 1;
        options.width += 1;
        attempts = 0;
      }
    }
    // fill in empty spaces with random letters
    if (options.fillBlanks != null) {
      final lettersToAdd = <String>[];
      var fillingBlanksCount = 0;
      var extraLettersCount = 0;
      var gridFillPercent = 0;
      Function extraLetterGenerator;
      // Custom fill blanks function
      if (options.fillBlanks is Function) {
        extraLetterGenerator = options.fillBlanks as Function;
      } else if (options.fillBlanks is String) {
        // Use the simple array pop mechanism for the input string
        lettersToAdd.addAll(
          (options.fillBlanks as String).toLowerCase().split(''),
        );
        extraLetterGenerator = () {
          if (lettersToAdd.isNotEmpty) {
            return lettersToAdd.removeLast();
          }
          fillingBlanksCount += 1;
          return '';
        };
      } else {
        // Use the default random letters
        extraLetterGenerator = () {
          return WSLetters[Random().nextInt(WSLetters.length)];
        };
      }
      // Fill all the blanks in the puzzle
      extraLettersCount = _fillBlanks(
        puzzle,
        extraLetterGenerator as String Function(),
      );
      // Warn the user that some letters were not used
      if (lettersToAdd.isNotEmpty) {
        output.warnings.add('Some extra letters provided were not used: $lettersToAdd');
      }
      // Extra letters not filled in the grid if allow blanks is false
      if (fillingBlanksCount > 0 && !options.allowExtraBlanks) {
        output.errors.add('$fillingBlanksCount extra letters were missing to fill the grid');
        return output;
      }
      gridFillPercent = (100 * (1 - extraLettersCount / (options.width * options.height))).round();
      debugPrint('Blanks filled with $extraLettersCount random letters');
      debugPrint('Final grid is filled at ${gridFillPercent.toStringAsFixed(0)}%');
    }
    output
      ..puzzle = puzzle
      ..wordsNotPlaced = _wordsNotPlaced;
    return output;
  }

  /// Returns the starting location and orientation of the specified words
  /// within the puzzle. Any words that are not found are returned in the
  /// notFound array.
  ///
  /// Example:
  /// ```
  /// final List<String> wl = ['hello', 'world', 'foo', 'bar', 'baz', 'dart'];
  /// final WSSettings ws = WSSettings();
  /// final WordSearch wordSearch = WordSearch();
  /// final WSNewPuzzle newPuzzle = wordSearch.newPuzzle(wl, ws);
  /// final WSSolved solved = wordSearch.solvePuzzle(newPuzzle.puzzle, ['dart']);
  /// // Outputs found and not found words
  /// ```
  ///
  WSSolved solvePuzzle(
    // The current state of the puzzle
    List<List<String>> puzzle,

    /// The words to be searched in the puzzle
    List<String> words,
  ) {
    final options = WSSettings(
      height: puzzle.length,
      width: puzzle[0].length,
    );
    // Create new instance of the solved interface
    final output = WSSolved();

    for (var i = 0, len = words.length; i < len; i++) {
      final word = words[i];
      final locations = _findBestLocations(puzzle, options, word);
      if (locations.isNotEmpty && locations[0].overlap == word.length) {
        locations[0].word = word;
        output.found.add(locations[0]);
      } else {
        output.notFound.add(word);
      }
    }
    // Return the output
    return output;
  }

  /// Returns the starting location and orientation of the specified words
  void setValidWordPositions({
    required double puzzleWidth,
    required double puzzleHeight,
  }) {
    _puzzleItemWidth = puzzleWidth / _width;
    _puzzleItemHeight = puzzleHeight / _width;

    for (final word in _validWordListPositions.keys) {
      final wordPositions = <Offset>[];
      for (final position in _validWordListPositions[word]!) {
        wordPositions.add(
          Offset(
            position.dx * _puzzleItemWidth!,
            position.dy * _puzzleItemHeight!,
          ),
        );
      }
      _validWordPositions[word] = wordPositions;
    }
  }

  /// Validate if the positions provided match an word in the puzzle
  /// and return the boolean result
  bool validateLine(
    List<Offset> positions,
    Color lineColor,
  ) {
    var valid = false;
    var foundWord = '';
    final calculationWidth = _puzzleItemWidth! / 1;
    final calculationHeight = _puzzleItemHeight! / 1;
    _validWordPositions.forEach((word, validPositions) {
      final validFirstXStartPosition = validPositions.first.dx - calculationWidth;
      final validFirstYStartPosition = validPositions.first.dy - calculationHeight;
      final validFirstXEndPosition = validPositions.first.dx + calculationWidth;
      final validFirstYEndPosition = validPositions.first.dy + calculationHeight;
      final validLastXStartPosition = validPositions.last.dx - calculationWidth;
      final validLastYStartPosition = validPositions.last.dy - calculationHeight;
      final validLastXEndPosition = validPositions.last.dx + calculationWidth;
      final validLastYEndPosition = validPositions.last.dy + calculationHeight;
      if ((positions.first.dx >= validFirstXStartPosition &&
                  positions.first.dx <= validFirstXEndPosition &&
                  positions.first.dy >= validFirstYStartPosition &&
                  positions.first.dy <= validFirstYEndPosition) &&
              (positions.last.dx >= validLastXStartPosition &&
                  positions.last.dx <= validLastXEndPosition &&
                  positions.last.dy >= validLastYStartPosition &&
                  positions.last.dy <= validLastYEndPosition) ||
          (positions.last.dx >= validFirstXStartPosition &&
                  positions.last.dx <= validFirstXEndPosition &&
                  positions.last.dy >= validFirstYStartPosition &&
                  positions.last.dy <= validFirstYEndPosition) &&
              (positions.first.dx >= validLastXStartPosition &&
                  positions.first.dx <= validLastXEndPosition &&
                  positions.first.dy >= validLastYStartPosition &&
                  positions.first.dy <= validLastYEndPosition)) {
        valid = true;
        foundWord = word;
      }
    });
    if (valid) {
      if (!_wordItems.firstWhere((item) => item.word == foundWord).found) {
        for (final item in _wordItems) {
          if (item.word == foundWord) {
            final updatedItem = item.copyWith(
              found: true,
              foundChipColor: lineColor,
            );
            _wordItems[_wordItems.indexOf(item)] = updatedItem;
          }
        }
      } else {
        valid = false;
      }
      _checkPuzzleCompleted();
    }
    emit(WordSearcherLoaded(puzzle: _puzzle!, words: _wordItems));
    return valid;
  }

  void _checkPuzzleCompleted() {
    if (_validWordListPositions.length == _wordItems.where((item) => item.found).length) {
      _onPuzzleCompleted();
    }
  }
}
