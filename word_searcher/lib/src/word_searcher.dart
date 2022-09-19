import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:word_searcher/src/cubit/word_searcher_cubit.dart';
import 'dart:math' as math;

class WordSearcher extends StatelessWidget {
  const WordSearcher({
    super.key,
    required this.onPuzzleCompleted,
    required this.words,
  });

  final VoidCallback onPuzzleCompleted;
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WordSearcherCubit(
        onPuzzleCompleted: onPuzzleCompleted,
        words: words,
      ),
      child: _WordSearcher(),
    );
  }
}

class _WordSearcher extends StatefulWidget {
  _WordSearcher({super.key});

  @override
  State<_WordSearcher> createState() => _WordSearcherState();
}

class _WordSearcherState extends State<_WordSearcher> {
  final _wordPuzzleKey = GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wordSearcherCubit = context.watch<WordSearcherCubit>();
  }

  @override
  Widget build(BuildContext context) {
    final wordSearcherCubit = context.watch<WordSearcherCubit>();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => wordSearcherCubit.setValidWordPositions(
        puzzleWidth: _wordPuzzleKey.currentContext!.size?.width ?? 0,
        puzzleHeight: _wordPuzzleKey.currentContext!.size?.height ?? 0,
      ),
    );

    return BlocBuilder<WordSearcherCubit, WordSearcherState>(
      builder: (context, state) {
        if (state is WordSearcherLoaded) {
          return Column(
            children: [
              Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    key: _wordPuzzleKey,
                    children: state.puzzle.puzzle
                            ?.map<Row>(
                              (row) => Row(
                                children: row.map((item) {
                                  final topLeftItem =
                                      state.puzzle.puzzle?.first == row && row.first == item;
                                  final topRightItem =
                                      state.puzzle.puzzle?.first == row && row.last == item;
                                  final bottomLeftItem =
                                      state.puzzle.puzzle?.last == row && row.first == item;
                                  final bottomRightItem =
                                      state.puzzle.puzzle?.last == row && row.last == item;
                                  return Expanded(
                                    child: AspectRatio(
                                      aspectRatio: 1,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            width: 0.5,
                                          ),
                                          borderRadius: BorderRadius.only(
                                            topLeft: topLeftItem
                                                ? const Radius.circular(5)
                                                : Radius.zero,
                                            topRight: topRightItem
                                                ? const Radius.circular(5)
                                                : Radius.zero,
                                            bottomLeft: bottomLeftItem
                                                ? const Radius.circular(5)
                                                : Radius.zero,
                                            bottomRight: bottomRightItem
                                                ? const Radius.circular(5)
                                                : Radius.zero,
                                          ),
                                        ),
                                        height: 50,
                                        child: Center(
                                          child: Text(item),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            )
                            .toList() ??
                        [],
                  ),
                  Positioned.fill(
                    child: _DrawOverlay(
                      onPathComplete: wordSearcherCubit.validateLine,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                children: state.words.map<Widget>(
                  (wordItem) {
                    final backgroundColor =
                        wordItem.found ? wordItem.foundChipColor : Colors.redAccent;
                    return Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(
                              8,
                            ),
                          ),
                          color: backgroundColor,
                        ),
                        child: Text(
                          wordItem.word,
                          style: TextStyle(
                            fontSize: 12,
                            color: backgroundColor.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ],
          );
        }
        return Container();
      },
    );
  }
}

class _DrawOverlay extends StatefulWidget {
  const _DrawOverlay({
    super.key,
    required this.onPathComplete,
  });

  final bool Function(List<Offset> path, Color selectedLineColor) onPathComplete;

  @override
  State<_DrawOverlay> createState() => _DrawOverlayState();
}

class _DrawOverlayState extends State<_DrawOverlay> {
  List<_DrawnLine> lines = <_DrawnLine>[];
  _DrawnLine line = _DrawnLine([], Colors.black, 2);
  Color selectedColor = Colors.black;
  double selectedWidth = 10;

  StreamController<List<_DrawnLine>> linesStreamController =
      StreamController<List<_DrawnLine>>.broadcast();
  StreamController<_DrawnLine> currentLineStreamController =
      StreamController<_DrawnLine>.broadcast();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            color: Colors.transparent,
            padding: const EdgeInsets.all(4),
            alignment: Alignment.topLeft,
            child: StreamBuilder<List<_DrawnLine>>(
              stream: linesStreamController.stream,
              builder: (context, snapshot) {
                return CustomPaint(
                  painter: _DrawPainter(
                    lines: lines,
                  ),
                );
              },
            ),
          ),
        ),
        GestureDetector(
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: RepaintBoundary(
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              padding: const EdgeInsets.all(4),
              color: Colors.transparent,
              alignment: Alignment.topLeft,
              child: StreamBuilder<_DrawnLine>(
                stream: currentLineStreamController.stream,
                builder: (context, snapshot) {
                  return CustomPaint(
                    painter: _DrawPainter(
                      lines: [line],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  void onPanStart(DragStartDetails details) {
    final box = context.findRenderObject()! as RenderBox;
    final point = box.globalToLocal(details.globalPosition);
    selectedColor = Color((math.Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(1.0);
    line = _DrawnLine([point], selectedColor, selectedWidth);
  }

  void onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject()! as RenderBox;
    final point = box.globalToLocal(details.globalPosition);

    final path = List<Offset>.from(line.path)..add(point);
    line = _DrawnLine(path, selectedColor, selectedWidth);
    currentLineStreamController.add(line);
  }

  void onPanEnd(DragEndDetails details) {
    if (widget.onPathComplete(line.path, selectedColor)) {
      lines = List.from(lines)..add(line);
      linesStreamController.add(lines);
    } else {
      line = _DrawnLine([], selectedColor, selectedWidth);
      currentLineStreamController.add(line);
    }
  }
}

class _DrawnLine {
  _DrawnLine(this.path, this.color, this.width);
  final List<Offset> path;
  final Color color;
  final double width;
}

class _DrawPainter extends CustomPainter {
  _DrawPainter({required this.lines});
  final List<_DrawnLine> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    for (var i = 0; i < lines.length; ++i) {
      paint
        ..color = lines[i].color
        ..strokeWidth = lines[i].width;
      if (lines[i].path.length > 1) {
        canvas.drawLine(lines[i].path.first, lines[i].path.last, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DrawPainter oldDelegate) {
    return true;
  }
}
