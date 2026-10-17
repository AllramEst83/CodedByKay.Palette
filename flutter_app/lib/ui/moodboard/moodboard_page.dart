import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/color_utils.dart';
import '../../core/dynamic_layout.dart';
import '../../models/board_models.dart';
import '../../models/swatch.dart';
import '../../services/app_messenger.dart';
import '../../services/export_service.dart';
import '../../services/image_service.dart';
import '../../services/picker_service.dart';
import '../../state/board_controller.dart';
import '../app_theme.dart';
import '../painters/board_painters.dart';
import '../responsive.dart';
import '../widgets/color_picker.dart';
import '../widgets/common.dart';
import '../widgets/image_drop_zone.dart';
import 'dynamic_board_view.dart';

class MoodBoardPage extends StatelessWidget {
  const MoodBoardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdaptiveWorkspace(
      controlsLabel: 'Board controls',
      controls: MoodBoardControls(),
      preview: MoodBoardPreview(),
    );
  }
}

Future<void> addBoardImages(BoardController board) async {
  final List<PickedImage> picked = await PickerService.pickImages(multiple: true);
  await board.addPickedImages(picked);
}

Future<void> exportBoard(BoardController board) async {
  try {
    if (board.mode == BoardMode.dynamic) {
      if (board.isEmpty) {
        AppMessenger.show('Nothing to export yet!', isError: true);
        return;
      }
      final DynamicBoardRenderer renderer = DynamicBoardRenderer(board);
      final bytes = await ImageService.renderToPng(
        dynamicCanvasW.round(),
        dynamicCanvasH.round(),
        renderer.paint,
      );
      await ExportService.savePng(bytes, 'mood-board.png');
      return;
    }
    final GridBoardPlan? plan = GridBoardPlan.from(board);
    if (plan == null) {
      AppMessenger.show('Nothing to export yet!', isError: true);
      return;
    }
    final bytes = await ImageService.renderToPng(plan.pixelWidth, plan.pixelHeight, plan.paint);
    await ExportService.savePng(bytes, 'mood-board.png');
  } catch (err) {
    AppMessenger.show('Error exporting image: $err', isError: true);
  }
}

class MoodBoardControls extends StatelessWidget {
  const MoodBoardControls({super.key});

  static const Map<String, String> _ratioLabels = <String, String>{
    '1:1': '1:1',
    '4:3': '4:3',
    '3:4': '3:4',
    '16:9': '16:9',
    'original': 'Original',
  };

  @override
  Widget build(BuildContext context) {
    final BoardController b = context.watch<BoardController>();
    final bool grid = b.mode == BoardMode.grid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ControlSection(
          title: 'Board',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: b.loading ? null : () => addBoardImages(b),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add images'),
              ),
              OutlinedButton.icon(
                onPressed: b.loading ? null : b.loadSampleBoard,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Sample board'),
              ),
              OutlinedButton.icon(
                onPressed: b.isEmpty ? null : () => exportBoard(b),
                icon: const Icon(Icons.download),
                label: const Text('Download PNG'),
              ),
              OutlinedButton.icon(
                onPressed: b.isEmpty ? null : () => _confirmClear(context, b),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.rose400),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear board'),
              ),
            ],
          ),
        ),
        ControlSection(
          title: 'Mode',
          child: SegmentedButton<BoardMode>(
            segments: const <ButtonSegment<BoardMode>>[
              ButtonSegment<BoardMode>(
                value: BoardMode.grid,
                icon: Icon(Icons.grid_view),
                label: Text('Grid'),
              ),
              ButtonSegment<BoardMode>(
                value: BoardMode.dynamic,
                icon: Icon(Icons.open_with),
                label: Text('Dynamic'),
              ),
            ],
            selected: <BoardMode>{b.mode},
            onSelectionChanged: (Set<BoardMode> s) => b.setMode(s.first),
          ),
        ),
        ControlSection(
          title: 'Extract palette',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: b.selectedImage == null ? null : () => b.extractSelectedPalette(),
                icon: const Icon(Icons.colorize),
                label: const Text('Extract from selected image'),
              ),
              if (b.selectedImage == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Select an image on the board first.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.slate400),
                  ),
                ),
              if (b.extractedColors.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _ExtractedSwatches(colors: b.extractedColors),
              ],
            ],
          ),
        ),
        if (!grid)
          ControlSection(
            title: 'Sticky notes',
            child: FilledButton.tonalIcon(
              onPressed: b.addStickyNote,
              icon: const Icon(Icons.sticky_note_2_outlined),
              label: const Text('Add sticky note'),
            ),
          ),
        if (grid) ...<Widget>[
          ControlSection(
            title: 'Columns',
            child: OptionChips<int>(
              options: const <int, String>{1: '1', 2: '2', 3: '3', 4: '4', 5: '5'},
              selected: b.columns,
              onSelected: b.setColumns,
            ),
          ),
          ControlSection(
            title: 'Cell ratio',
            child: OptionChips<String>(
              options: _ratioLabels,
              selected: b.ratio,
              tooltips: const <Object?, String>{'original': "Keep each image's original aspect ratio"},
              onSelected: b.setRatio,
            ),
          ),
          ControlSection(
            title: 'Gutter',
            trailing: Text('${b.gutter.round()} px'),
            child: LabeledSlider(
              value: b.gutter,
              min: 0,
              max: 64,
              label: '${b.gutter.round()} px',
              semanticLabel: 'Gutter',
              onChanged: b.setGutter,
            ),
          ),
          ControlSection(
            title: 'Padding',
            trailing: Text('${b.padding.round()} px'),
            child: LabeledSlider(
              value: b.padding,
              min: 0,
              max: 80,
              label: '${b.padding.round()} px',
              semanticLabel: 'Padding',
              onChanged: b.setPadding,
            ),
          ),
          ControlSection(
            title: 'Corner radius',
            trailing: Text('${b.radius.round()} px'),
            child: LabeledSlider(
              value: b.radius,
              min: 0,
              max: 40,
              label: '${b.radius.round()} px',
              semanticLabel: 'Corner radius',
              onChanged: b.setRadius,
            ),
          ),
        ],
        ControlSection(title: 'Background', child: _BackgroundPicker(board: b)),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context, BoardController board) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear the board?'),
        content: const Text('This removes every image, note and palette from the board.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok ?? false) board.clear();
  }
}

class _BackgroundPicker extends StatelessWidget {
  const _BackgroundPicker({required this.board});

  final BoardController board;

  @override
  Widget build(BuildContext context) {
    final String current = board.bgColor.toLowerCase();
    final bool isPreset =
        backgroundPresets.any((BackgroundPreset p) => p.hex.toLowerCase() == current);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final BackgroundPreset p in backgroundPresets)
          _BgSwatch(
            label: '${p.name} background',
            color: Color(parseHexColor(p.hex)),
            selected: p.hex.toLowerCase() == current,
            onTap: () => board.setBgColor(p.hex),
          ),
        _BgSwatch(
          label: 'Custom background color',
          color: isPreset ? null : Color(parseHexColor(board.bgColor)),
          icon: Icons.colorize,
          selected: !isPreset,
          onTap: () async {
            final String? picked = await showColorPickerDialog(context, board.bgColor);
            if (picked != null) board.setBgColor(picked);
          },
        ),
      ],
    );
  }
}

class _BgSwatch extends StatelessWidget {
  const _BgSwatch({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color ?? AppColors.slate800,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? AppColors.indigo500 : AppColors.slate700,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check, size: 18, color: _checkColor(color))
                    : (icon == null ? null : Icon(icon, size: 18, color: AppColors.slate400)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _checkColor(Color? c) {
    if (c == null) return Colors.white;
    return c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

class _ExtractedSwatches extends StatelessWidget {
  const _ExtractedSwatches({required this.colors});

  final List<Swatch> colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (int i = 0; i < colors.length; i++)
          Semantics(
            button: true,
            label: 'Copy ${colors[i].hex}',
            child: Material(
              color: Color(colors[i].argb),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.slate700),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => AppMessenger.copy(colors[i].hex),
                child: SizedBox(
                  width: 84,
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          '#${i + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: colors[i].isLight ? AppColors.slate900 : Colors.white,
                          ),
                        ),
                        Text(
                          colors[i].hex,
                          style: TextStyle(
                            fontFamily: monoFont,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors[i].isLight ? AppColors.slate900 : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class MoodBoardPreview extends StatelessWidget {
  const MoodBoardPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final BoardController b = context.watch<BoardController>();
    return ImageDropZone(
      onImages: b.addPickedImages,
      child: _boardColumn(b),
    );
  }

  Widget _boardColumn(BoardController b) {
    return Column(
      children: <Widget>[
        if (b.loading) const LinearProgressIndicator(),
        const BoardItemStrip(),
        Expanded(
          child: b.isEmpty
              ? (b.loading ? const Padding(padding: EdgeInsets.all(16), child: ShimmerBox()) : const _EmptyBoard())
              : (b.mode == BoardMode.grid ? const _GridCanvas() : const DynamicBoardView()),
        ),
      ],
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    final BoardController b = context.read<BoardController>();
    return EmptyState(
      icon: Icons.dashboard_customize_outlined,
      title: 'Build a mood board',
      message: 'Add images to arrange them in a grid or a free-form canvas, or load the sample board.',
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () => addBoardImages(b),
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add images'),
        ),
        OutlinedButton.icon(
          onPressed: b.loadSampleBoard,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Sample board'),
        ),
      ],
    );
  }
}

class _GridCanvas extends StatelessWidget {
  const _GridCanvas();

  @override
  Widget build(BuildContext context) {
    final BoardController b = context.watch<BoardController>();
    final GridBoardPlan? plan = GridBoardPlan.from(b);
    if (plan == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: math.min(plan.width, 1400)),
              child: Semantics(
                label: 'Mood board grid with ${plan.items.length} items',
                image: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: plan.width / plan.height,
                    child: CustomPaint(painter: GridBoardPainter(plan)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.pixelWidth} × ${plan.pixelHeight} px',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.slate400, fontFamily: monoFont),
          ),
        ],
      ),
    );
  }
}

/// Horizontal strip of board items: select, reorder and remove.
class BoardItemStrip extends StatelessWidget {
  const BoardItemStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final BoardController b = context.watch<BoardController>();
    final List<OrderedBoardItem> items = b.orderedItems;
    if (items.isEmpty) return const SizedBox.shrink();

    final OrderedBoardItem? selected = items.cast<OrderedBoardItem?>().firstWhere(
          (OrderedBoardItem? i) => i!.id == b.selectedId,
          orElse: () => null,
        );
    final int selectedIndex = selected == null ? -1 : items.indexOf(selected);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(10),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final OrderedBoardItem item = items[index];
                return _Thumb(item: item, selected: item.id == b.selectedId, position: index + 1);
              },
            ),
          ),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      selected is BoardImage ? selected.name : 'Palette from ${(selected as SwatchGroup).sourceName}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move earlier',
                    onPressed: selectedIndex > 0 ? () => b.moveItem(selected.id, -1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Move later',
                    onPressed: selectedIndex < items.length - 1
                        ? () => b.moveItem(selected.id, 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  IconButton(
                    tooltip: selected is BoardImage ? 'Remove image' : 'Delete palette',
                    color: AppColors.rose400,
                    onPressed: () => selected is BoardImage
                        ? b.removeImage(selected.id)
                        : b.removeSwatchGroup(selected.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, required this.selected, required this.position});

  final OrderedBoardItem item;
  final bool selected;
  final int position;

  @override
  Widget build(BuildContext context) {
    final BoardController b = context.read<BoardController>();
    final OrderedBoardItem it = item;
    final String label = it is BoardImage
        ? it.name
        : 'Extracted palette from ${(it as SwatchGroup).sourceName}';
    return Semantics(
      button: true,
      selected: selected,
      label: 'Item $position: $label${selected ? ', selected' : ''}',
      child: Tooltip(
        message: label,
        child: Material(
          color: AppColors.slate900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? AppColors.indigo500 : AppColors.slate700,
              width: selected ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => b.select(selected ? null : it.id),
            child: SizedBox(
              width: 64,
              height: 64,
              child: it is BoardImage
                  ? RawImage(image: it.image, fit: BoxFit.cover)
                  : Column(
                      children: <Widget>[
                        for (final Swatch s in (it as SwatchGroup).colors.take(6))
                          Expanded(child: ColoredBox(color: Color(s.argb), child: const SizedBox.expand())),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
