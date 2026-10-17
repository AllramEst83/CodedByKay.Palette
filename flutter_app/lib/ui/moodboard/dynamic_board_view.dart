import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/color_utils.dart';
import '../../core/dynamic_layout.dart';
import '../../models/board_models.dart';
import '../../models/swatch.dart';
import '../../state/board_controller.dart';
import '../app_theme.dart';

/// Free-form 1600x1000 logical canvas: drag, resize, select, notes, palettes.
///
/// Pinch to zoom and drag the background to pan (useful on phones, where the
/// whole canvas is scaled down to fit).
class DynamicBoardView extends StatefulWidget {
  const DynamicBoardView({super.key});

  @override
  State<DynamicBoardView> createState() => _DynamicBoardViewState();
}

class _DynamicBoardViewState extends State<DynamicBoardView> {
  final TransformationController _viewer = TransformationController();

  @override
  void dispose() {
    _viewer.dispose();
    super.dispose();
  }

  double get _zoom => _viewer.value.getMaxScaleOnAxis();

  @override
  Widget build(BuildContext context) {
    final BoardController board = context.watch<BoardController>();
    return Column(
      children: <Widget>[
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double scale = math.max(
                0.05,
                math.min(
                  (constraints.maxWidth - 24) / dynamicCanvasW,
                  (constraints.maxHeight - 24) / dynamicCanvasH,
                ),
              );
              final Size canvasSize = Size(dynamicCanvasW * scale, dynamicCanvasH * scale);
              return Center(
                child: Semantics(
                  label: 'Dynamic mood board canvas',
                  container: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: InteractiveViewer(
                      transformationController: _viewer,
                      minScale: 1,
                      maxScale: 5,
                      child: SizedBox(
                        width: canvasSize.width,
                        height: canvasSize.height,
                        child: ColoredBox(
                          color: Color(parseHexColor(board.bgColor)),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: <Widget>[
                              // Tapping empty canvas clears the selection.
                              Positioned.fill(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => board.select(null),
                                ),
                              ),
                              for (final BoardItem item in board.zOrderedItems)
                                _ItemShell(
                                  key: ValueKey<String>(item.id),
                                  item: item,
                                  scale: scale,
                                  zoom: () => _zoom,
                                  selected: item.id == board.selectedId,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const _SelectionBar(),
      ],
    );
  }
}

class _ItemShell extends StatefulWidget {
  const _ItemShell({
    required this.item,
    required this.scale,
    required this.zoom,
    required this.selected,
    super.key,
  });

  final BoardItem item;
  final double scale;
  final double Function() zoom;
  final bool selected;

  @override
  State<_ItemShell> createState() => _ItemShellState();
}

class _ItemShellState extends State<_ItemShell> {
  final FocusNode _focus = FocusNode();
  Offset _dragStartPointer = Offset.zero;
  Offset _dragStartItem = Offset.zero;
  Size _resizeStartSize = Size.zero;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  double get _unit => widget.scale * widget.zoom();

  void _activate(BoardController board) {
    board.select(widget.item.id);
    board.bringToFront(widget.item.id);
    _focus.requestFocus();
  }

  void _onPanStart(DragStartDetails d, BoardController board) {
    _activate(board);
    _dragStartPointer = d.globalPosition;
    _dragStartItem = Offset(widget.item.x, widget.item.y);
  }

  void _onPanUpdate(DragUpdateDetails d, BoardController board) {
    final Offset delta = (d.globalPosition - _dragStartPointer) / _unit;
    final BoardPoint p = clampPosition(
      _dragStartItem.dx + delta.dx,
      _dragStartItem.dy + delta.dy,
      widget.item.w,
      widget.item.h,
    );
    board.updateGeometry(widget.item.id, x: p.x, y: p.y);
  }

  void _onResizeStart(DragStartDetails d, BoardController board) {
    _dragStartPointer = d.globalPosition;
    _resizeStartSize = Size(widget.item.w, widget.item.h);
  }

  void _onResizeUpdate(DragUpdateDetails d, BoardController board) {
    final Offset delta = (d.globalPosition - _dragStartPointer) / _unit;
    final double rawW = math.max(minResizeSize, _resizeStartSize.width + delta.dx);
    final double rawH = math.max(minResizeSize, _resizeStartSize.height + delta.dy);
    final ({double w, double h}) size = clampSize(widget.item.x, widget.item.y, rawW, rawH);
    board.updateGeometry(widget.item.id, w: size.w, h: size.h);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event, BoardController board) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (board.editingNoteId != null) return KeyEventResult.ignored;
    final BoardItem item = widget.item;
    final double step = HardwareKeyboard.instance.isShiftPressed ? 20 : 4;
    double x = item.x;
    double y = item.y;
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      x -= step;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      x += step;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      y -= step;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      y += step;
    } else if (key == LogicalKeyboardKey.escape) {
      board.select(null);
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    final BoardPoint p = clampPosition(x, y, item.w, item.h);
    board.updateGeometry(item.id, x: p.x, y: p.y);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final BoardController board = context.read<BoardController>();
    final BoardItem item = widget.item;
    final double s = widget.scale;
    final bool resizable = item.kind != BoardItemKind.image;

    return Positioned(
      left: item.x * s,
      top: item.y * s,
      width: item.w * s,
      height: item.h * s,
      child: Transform.rotate(
        angle: item.rotation * math.pi / 180,
        child: Focus(
          focusNode: _focus,
          onFocusChange: (bool focused) {
            if (focused && board.selectedId != item.id) board.select(item.id);
          },
          onKeyEvent: (FocusNode node, KeyEvent e) => _onKey(node, e, board),
          child: Semantics(
            button: true,
            selected: widget.selected,
            label: _semanticLabel(item),
            hint: 'Drag to move. Use arrow keys to nudge.',
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onTapDown: (_) => _activate(board),
                    onDoubleTap: item is StickyNote ? () => board.beginEditingNote(item.id) : null,
                    onPanStart: (DragStartDetails d) => _onPanStart(d, board),
                    onPanUpdate: (DragUpdateDetails d) => _onPanUpdate(d, board),
                    child: _ItemBody(item: item, scale: s),
                  ),
                ),
                if (widget.selected)
                  Positioned(
                    left: -4,
                    top: -4,
                    right: -4,
                    bottom: -4,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.indigo500, width: 2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                if (widget.selected && resizable)
                  Positioned(
                    right: -18,
                    bottom: -18,
                    width: 36,
                    height: 36,
                    child: Semantics(
                      label: 'Resize handle',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        dragStartBehavior: DragStartBehavior.down,
                        onPanStart: (DragStartDetails d) => _onResizeStart(d, board),
                        onPanUpdate: (DragUpdateDetails d) => _onResizeUpdate(d, board),
                        child: Center(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.indigo500,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel(BoardItem item) {
    if (item is BoardImage) return item.name.isEmpty ? 'Mood board image' : item.name;
    if (item is StickyNote) return 'Sticky note: ${item.text}';
    if (item is SwatchGroup) return 'Extracted palette from ${item.sourceName}';
    return 'Board item';
  }
}

class _ItemBody extends StatelessWidget {
  const _ItemBody({required this.item, required this.scale});

  final BoardItem item;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final BoardItem it = item;
    if (it is BoardImage) {
      return RawImage(image: it.image, fit: BoxFit.cover);
    }
    if (it is StickyNote) {
      return _NoteBody(note: it, scale: scale);
    }
    if (it is SwatchGroup) {
      final double rowH = it.h / it.colors.length;
      final double font = math.max(9, math.min(16, (rowH * 0.4).roundToDouble())) * scale;
      return Column(
        children: <Widget>[
          for (final Swatch c in it.colors)
            Expanded(
              child: ColoredBox(
                color: Color(c.argb),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 10 * scale),
                    child: Text(
                      c.hex,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontFamily: monoFont,
                        fontWeight: FontWeight.w700,
                        fontSize: font,
                        color: c.isLight ? AppColors.slate900 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _NoteBody extends StatefulWidget {
  const _NoteBody({required this.note, required this.scale});

  final StickyNote note;
  final double scale;

  @override
  State<_NoteBody> createState() => _NoteBodyState();
}

class _NoteBodyState extends State<_NoteBody> {
  late final TextEditingController _text = TextEditingController(text: widget.note.text);
  late final FocusNode _focus = FocusNode(
    onKeyEvent: (FocusNode node, KeyEvent e) {
      if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
        node.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );
  bool _wasEditing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus || !_wasEditing) return;
    _commit();
  }

  void _commit() {
    _wasEditing = false;
    final BoardController board = context.read<BoardController>();
    board.updateNote(widget.note.id, text: _text.text);
    board.endEditingNote();
  }

  @override
  Widget build(BuildContext context) {
    final BoardController board = context.watch<BoardController>();
    final StickyNote note = widget.note;
    final bool editing = board.editingNoteId == note.id;
    final TextStyle style = TextStyle(
      fontFamily: sansFont,
      fontWeight: FontWeight.w600,
      fontSize: math.max(6, 18 * widget.scale),
      height: 22 / 18,
      color: Color(parseHexColor(note.textColor)),
    );

    if (editing && !_wasEditing) {
      _wasEditing = true;
      _text.text = note.text;
      _text.selection = TextSelection(baseOffset: 0, extentOffset: note.text.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(parseHexColor(note.color)),
        borderRadius: BorderRadius.circular(12 * widget.scale),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12 * widget.scale),
        child: Center(
          child: editing
              ? TextField(
                  controller: _text,
                  focusNode: _focus,
                  style: style,
                  textAlign: TextAlign.center,
                  maxLines: null,
                  decoration: const InputDecoration.collapsed(hintText: 'Note text'),
                  cursorColor: Color(parseHexColor(note.textColor)),
                )
              : Text(
                  note.text,
                  textAlign: TextAlign.center,
                  style: style,
                  overflow: TextOverflow.fade,
                ),
        ),
      ),
    );
  }
}

/// Actions for the selected note or palette, kept outside the canvas so touch
/// targets stay full-size regardless of the canvas zoom.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar();

  @override
  Widget build(BuildContext context) {
    final BoardController board = context.watch<BoardController>();
    final String? id = board.selectedId;
    final BoardItem? item = id == null ? null : board.findItem(id);

    final List<Widget> actions = <Widget>[];
    if (item is StickyNote) {
      actions
        ..add(IconButton(
          tooltip: 'Edit note text',
          onPressed: () => board.beginEditingNote(item.id),
          icon: const Icon(Icons.edit_outlined),
        ))
        ..addAll(<Widget>[
          for (final String color in defaultNoteColors)
            Semantics(
              button: true,
              selected: item.color == color,
              label: 'Set note color $color',
              child: InkResponse(
                onTap: () => board.updateNote(item.id, color: color),
                radius: 24,
                child: SizedBox(
                  width: 44,
                  height: 48,
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Color(parseHexColor(color)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: item.color == color ? AppColors.indigo500 : AppColors.slate700,
                          width: item.color == color ? 3 : 1,
                        ),
                      ),
                      child: item.color == color
                          ? const Icon(Icons.check, size: 14, color: Colors.black)
                          : null,
                    ),
                  ),
                ),
              ),
            ),
        ])
        ..add(IconButton(
          tooltip: 'Delete note',
          color: AppColors.rose400,
          onPressed: () => board.removeNote(item.id),
          icon: const Icon(Icons.delete_outline),
        ));
    } else if (item is SwatchGroup) {
      actions.add(IconButton(
        tooltip: 'Delete extracted palette',
        color: AppColors.rose400,
        onPressed: () => board.removeSwatchGroup(item.id),
        icon: const Icon(Icons.delete_outline),
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        ),
      ),
    );
  }
}
