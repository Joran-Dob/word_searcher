part of 'word_searcher_cubit.dart';

@immutable
abstract class WordSearcherState {}

class WordSearcherInitial extends WordSearcherState {}

class WordSearcherLoading extends WordSearcherState {}

class WordSearcherLoaded extends WordSearcherState {
  final WSNewPuzzle puzzle;
  final List<WordItem> words;

  WordSearcherLoaded({
    required this.puzzle,
    required this.words,
  });
}
