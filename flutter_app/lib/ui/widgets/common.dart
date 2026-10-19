import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../responsive.dart';

/// Labeled group used throughout the control panels.
class ControlSection extends StatelessWidget {
  const ControlSection({
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.slate400,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Single-select group of chips (check mark + fill, so state is not color-only).
class OptionChips<T> extends StatelessWidget {
  const OptionChips({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.tooltips = const <Object?, String>{},
    this.columns = 3,
    super.key,
  });

  /// Value -> label.
  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Map<Object?, String> tooltips;

  /// Grid columns of the segmented layout used on wide screens.
  final int columns;

  @override
  Widget build(BuildContext context) {
    if (isWideLayout(context)) return _buildSegmented(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: <Widget>[
        for (final MapEntry<T, String> entry in options.entries)
          Tooltip(
            message: tooltips[entry.key] ?? entry.value,
            child: ChoiceChip(
              label: Text(entry.value),
              selected: entry.key == selected,
              onSelected: (_) => onSelected(entry.key),
              materialTapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
      ],
    );
  }

  /// Equal-width segmented grid in a recessed tray (like the original web UI).
  Widget _buildSegmented(BuildContext context) {
    const double gap = 4;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.slate950,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate700),
      ),
      child: Padding(
        padding: const EdgeInsets.all(gap),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int cols = options.length < columns
                ? options.length
                : columns;
            final double cellWidth =
                (constraints.maxWidth - gap * (cols - 1)) / cols - 0.01;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final MapEntry<T, String> entry in options.entries)
                  SizedBox(
                    width: cellWidth,
                    height: 36,
                    child: _Segment(
                      label: entry.value,
                      tooltip: tooltips[entry.key] ?? entry.value,
                      selected: entry.key == selected,
                      onTap: () => onSelected(entry.key),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? AppColors.indigo600 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : AppColors.slate400,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slider with a live value label.
class LabeledSlider extends StatelessWidget {
  const LabeledSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final double min;
  final double max;
  final String label;
  final String? semanticLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: (max - min).round(),
        label: label,
        onChanged: onChanged,
      ),
    );
  }
}

/// Animated shimmer block used as a loading placeholder.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({this.borderRadius = 12, super.key});

  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = _controller.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment(-1 + 3 * t - 1, 0),
                end: Alignment(1 + 3 * t - 1, 0),
                colors: const <Color>[
                  AppColors.slate800,
                  AppColors.slate700,
                  AppColors.slate800,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Centered empty-state card with a primary and optional secondary action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 56, color: AppColors.slate400),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.slate400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
