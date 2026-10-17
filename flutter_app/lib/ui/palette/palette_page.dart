import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../../core/kmeans.dart';
import '../../core/palette_theme.dart';
import '../../models/swatch.dart';
import '../../services/app_messenger.dart';
import '../../services/export_service.dart';
import '../../services/image_service.dart';
import '../../services/picker_service.dart';
import '../../state/palette_controller.dart';
import '../app_theme.dart';
import '../painters/palette_composite.dart';
import '../responsive.dart';
import '../widgets/common.dart';

class PalettePage extends StatelessWidget {
  const PalettePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdaptiveWorkspace(
      controlsLabel: 'Palette controls',
      controls: PaletteControls(),
      preview: PalettePreview(),
    );
  }
}

Future<void> pickPaletteImage(PaletteController controller) async {
  final List<PickedImage> picked = await PickerService.pickImages();
  if (picked.isEmpty) return;
  await controller.loadBytes(picked.first.bytes, name: picked.first.name);
}

Future<void> exportPaletteComposite(PaletteController controller) async {
  final image = controller.image;
  if (image == null || controller.displayedColors.isEmpty) {
    AppMessenger.show('Nothing to export yet!', isError: true);
    return;
  }
  final PaletteCompositePlan plan = PaletteCompositePlan.compute(
    imageWidth: image.width,
    imageHeight: image.height,
    colors: controller.displayedColors,
    showHex: controller.showHexText,
    showRgb: controller.showRgbText,
  );
  try {
    final bytes = await ImageService.renderToPng(
      plan.pixelWidth,
      plan.pixelHeight,
      (canvas, size) => plan.paint(canvas, size, image),
    );
    await ExportService.savePng(bytes, 'palette-composite.png');
  } catch (err) {
    AppMessenger.show('Error exporting image: $err', isError: true);
  }
}

class PaletteControls extends StatelessWidget {
  const PaletteControls({super.key});

  static const Map<SortMode, String> _sortLabels = <SortMode, String>{
    SortMode.prominence: 'Prominence',
    SortMode.luminance: 'Luminance',
    SortMode.hue: 'Hue',
  };

  static const Map<String, String> _themeTips = <String, String>{
    'original': 'Show the raw extracted colors, no transform applied',
    'pastel': 'Soft, light, desaturated tones',
    'neon': 'Bold, highly saturated, glowing tones',
    'muted': 'Heavily desaturated, subdued tones',
    'vivid': 'Punchy, boosted-saturation colors',
    'dark': 'Deepened, shadowy, low-lightness tones',
  };

  static const Map<String, String> _harmonyLabels = <String, String>{
    'complementary': 'Complementary',
    'analogous': 'Analogous',
    'triadic': 'Triadic',
    'tetradic': 'Tetradic',
  };

  static const Map<String, String> _harmonyTips = <String, String>{
    'complementary': 'Base color plus its opposite on the color wheel — high contrast',
    'analogous': 'Base color plus its neighbors on the color wheel — calm and cohesive',
    'triadic': 'Three hues evenly spaced around the color wheel — balanced and vibrant',
    'tetradic': 'Four hues evenly spaced around the color wheel — rich and varied',
  };

  @override
  Widget build(BuildContext context) {
    final PaletteController c = context.watch<PaletteController>();
    final String themeSelection = c.activeTheme ?? (c.activeHarmony == null ? 'original' : '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ControlSection(
          title: 'Image',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: c.loading ? null : () => pickPaletteImage(c),
                icon: const Icon(Icons.upload_file),
                label: const Text('Choose image'),
              ),
              OutlinedButton.icon(
                onPressed: c.loading ? null : c.loadSample,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Sample'),
              ),
              OutlinedButton.icon(
                onPressed: c.hasImage ? () => exportPaletteComposite(c) : null,
                icon: const Icon(Icons.download),
                label: const Text('Download PNG'),
              ),
            ],
          ),
        ),
        ControlSection(
          title: 'Number of colors',
          trailing: Text('${c.paletteCount} Colors'),
          child: LabeledSlider(
            value: c.paletteCount.toDouble(),
            min: PaletteController.minCount.toDouble(),
            max: PaletteController.maxCount.toDouble(),
            label: '${c.paletteCount}',
            semanticLabel: 'Number of colors',
            onChanged: (double v) => c.setPaletteCount(v.round()),
          ),
        ),
        ControlSection(
          title: 'Sort by',
          child: OptionChips<SortMode>(
            options: _sortLabels,
            selected: c.sortMode,
            onSelected: c.setSortMode,
          ),
        ),
        ControlSection(
          title: 'Theme',
          child: OptionChips<String>(
            options: <String, String>{
              'original': 'Original',
              for (final String n in themeNames) n: '${n[0].toUpperCase()}${n.substring(1)}',
            },
            selected: themeSelection,
            tooltips: _themeTips,
            onSelected: c.applyThemeByName,
          ),
        ),
        ControlSection(
          title: 'Harmony',
          trailing: _BaseColorIndicator(color: c.baseColor),
          child: OptionChips<String>(
            options: _harmonyLabels,
            selected: c.activeHarmony,
            tooltips: _harmonyTips,
            onSelected: c.applyHarmonyByName,
          ),
        ),
        ControlSection(
          title: 'Labels',
          child: Column(
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show HEX text'),
                value: c.showHexText,
                onChanged: c.setShowHexText,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show RGB text'),
                value: c.showRgbText,
                onChanged: c.setShowRgbText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BaseColorIndicator extends StatelessWidget {
  const _BaseColorIndicator({required this.color});

  final Swatch? color;

  @override
  Widget build(BuildContext context) {
    final Swatch? c = color;
    return Semantics(
      label: 'Harmony base color ${c?.hex ?? 'none'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Base '),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: c == null ? AppColors.indigo500 : Color(c.argb),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.slate700),
            ),
          ),
          const SizedBox(width: 6),
          Text(c?.hex ?? '—', style: const TextStyle(fontFamily: monoFont, fontSize: 12)),
        ],
      ),
    );
  }
}

class PalettePreview extends StatelessWidget {
  const PalettePreview({super.key});

  @override
  Widget build(BuildContext context) {
    final PaletteController c = context.watch<PaletteController>();

    if (!c.hasImage) {
      if (c.loading) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: ShimmerBox(borderRadius: 16),
        );
      }
      return EmptyState(
        icon: Icons.palette_outlined,
        title: 'Extract a color palette',
        message: 'Choose an image to pull its dominant colors, or try the sample.',
        actions: <Widget>[
          FilledButton.icon(
            onPressed: () => pickPaletteImage(c),
            icon: const Icon(Icons.upload_file),
            label: const Text('Choose image'),
          ),
          OutlinedButton.icon(
            onPressed: c.loadSample,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Use sample'),
          ),
        ],
      );
    }

    return Stack(
      children: <Widget>[
        const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CompositeView(),
              SizedBox(height: 16),
              _SwatchGrid(),
            ],
          ),
        ),
        if (c.loading)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
      ],
    );
  }
}

class _CompositeView extends StatelessWidget {
  const _CompositeView();

  @override
  Widget build(BuildContext context) {
    final PaletteController c = context.watch<PaletteController>();
    final image = c.image;
    if (image == null || c.displayedColors.isEmpty) {
      return const AspectRatio(aspectRatio: 3 / 2, child: ShimmerBox(borderRadius: 16));
    }
    final PaletteCompositePlan plan = PaletteCompositePlan.compute(
      imageWidth: image.width,
      imageHeight: image.height,
      colors: c.displayedColors,
      showHex: c.showHexText,
      showRgb: c.showRgbText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            // Cap the preview height so tall images don't push swatches off-screen.
            constraints: BoxConstraints(
              maxWidth: math.min(plan.width, 1200),
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Semantics(
              label: 'Palette preview of ${c.imageName ?? 'image'} with '
                  '${c.displayedColors.length} colors',
              image: true,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: plan.width / plan.height,
                  child: CustomPaint(painter: PaletteCompositePainter(plan: plan, image: image)),
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
    );
  }
}

class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid();

  @override
  Widget build(BuildContext context) {
    final PaletteController c = context.watch<PaletteController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = math.max(2, (constraints.maxWidth / 150).floor());
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: <Widget>[
                for (int i = 0; i < c.displayedColors.length; i++)
                  SwatchTile(
                    swatch: c.displayedColors[i],
                    index: i,
                    isBase: i == c.baseColorIndex,
                    onCopy: () => AppMessenger.copy(c.displayedColors[i].hex),
                    onSetBase: () {
                      c.setBaseColorIndex(i);
                      AppMessenger.show('Harmony base set to ${c.displayedColors[i].hex}');
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Tap a swatch to copy its HEX. Long-press or right-click to use it as the harmony base.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate400),
        ),
      ],
    );
  }
}

class SwatchTile extends StatelessWidget {
  const SwatchTile({
    required this.swatch,
    required this.index,
    required this.isBase,
    required this.onCopy,
    required this.onSetBase,
    super.key,
  });

  final Swatch swatch;
  final int index;
  final bool isBase;
  final VoidCallback onCopy;
  final VoidCallback onSetBase;

  @override
  Widget build(BuildContext context) {
    final Color fg = swatch.isLight ? AppColors.slate900 : Colors.white;
    final Color badge = swatch.isLight ? const Color(0x26000000) : const Color(0x33FFFFFF);
    return Semantics(
      button: true,
      label: 'Swatch ${index + 1}, ${swatch.hex}${isBase ? ', harmony base' : ''}. '
          'Activate to copy.',
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        const CustomSemanticsAction(label: 'Use as harmony base'): onSetBase,
      },
      child: Material(
        color: Color(swatch.argb),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isBase ? AppColors.indigo500 : AppColors.slate700,
            width: isBase ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onSecondaryTap: onSetBase,
          child: InkWell(
            onTap: onCopy,
            onLongPress: onSetBase,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: badge,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isBase)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.anchor, size: 14, color: fg),
                            const SizedBox(width: 2),
                            Text('BASE',
                                style: TextStyle(
                                    color: fg, fontSize: 10, fontWeight: FontWeight.w800)),
                          ],
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    swatch.hex,
                    style: TextStyle(
                      fontFamily: monoFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: fg,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    swatch.rgbLabel,
                    style: TextStyle(fontFamily: monoFont, fontSize: 11, color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
