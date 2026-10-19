import 'package:flutter/material.dart';

import 'widgets/panel_card.dart';

/// Width-based layout classes (never platform/device-based).
enum FormFactor { narrow, medium, wide }

const double mediumBreakpoint = 600;
const double wideBreakpoint = 1024;

/// Widest the wide layout grows; extra window width becomes side margin.
const double wideContentMaxWidth = 1560;

/// Whether the wide (desktop/web) layout applies at the current width.
bool isWideLayout(BuildContext context) =>
    formFactorForWidth(MediaQuery.sizeOf(context).width) == FormFactor.wide;

FormFactor formFactorForWidth(double width) {
  if (width >= wideBreakpoint) return FormFactor.wide;
  if (width >= mediumBreakpoint) return FormFactor.medium;
  return FormFactor.narrow;
}

/// Lays out a preview and its controls according to the available space:
///
/// * wide: centered max-width page, controls card on the left of the preview
/// * medium landscape: controls in a left side panel
/// * medium portrait: controls in a collapsible panel under the preview
/// * narrow: controls in a modal bottom sheet opened from a button
class AdaptiveWorkspace extends StatefulWidget {
  const AdaptiveWorkspace({
    required this.preview,
    required this.controls,
    this.controlsLabel = 'Controls',
    super.key,
  });

  final Widget preview;
  final Widget controls;
  final String controlsLabel;

  @override
  State<AdaptiveWorkspace> createState() => _AdaptiveWorkspaceState();
}

class _AdaptiveWorkspaceState extends State<AdaptiveWorkspace> {
  bool _bottomPanelOpen = true;

  Widget _panel(Widget child) =>
      SingleChildScrollView(padding: const EdgeInsets.all(16), child: child);

  Future<void> _openSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController controller) =>
            SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: widget.controls,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final FormFactor factor = formFactorForWidth(constraints.maxWidth);
        final bool landscape = constraints.maxWidth > constraints.maxHeight;
        final ColorScheme scheme = Theme.of(context).colorScheme;

        if (factor == FormFactor.wide) {
          // Centered "dashboard": a controls card beside the preview area,
          // both inset from the window edges and capped in width.
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: wideContentMaxWidth),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 360,
                      child: PanelCard(
                        title: widget.controlsLabel,
                        icon: Icons.tune,
                        expand: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: widget.controls,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: widget.preview),
                  ],
                ),
              ),
            ),
          );
        }

        if (factor == FormFactor.medium && landscape) {
          return Row(
            children: <Widget>[
              SizedBox(
                width: 320,
                child: Material(
                  color: scheme.surface,
                  shape: Border(right: BorderSide(color: scheme.outline)),
                  child: _panel(widget.controls),
                ),
              ),
              Expanded(child: widget.preview),
            ],
          );
        }

        if (factor == FormFactor.medium) {
          return Column(
            children: <Widget>[
              Expanded(child: widget.preview),
              Material(
                color: scheme.surface,
                shape: Border(top: BorderSide(color: scheme.outline)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      title: Text(widget.controlsLabel),
                      trailing: Icon(
                        _bottomPanelOpen
                            ? Icons.expand_more
                            : Icons.expand_less,
                      ),
                      onTap: () =>
                          setState(() => _bottomPanelOpen = !_bottomPanelOpen),
                    ),
                    if (_bottomPanelOpen)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.4,
                        ),
                        child: _panel(widget.controls),
                      ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: <Widget>[
            Expanded(child: widget.preview),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _openSheet,
                  icon: const Icon(Icons.tune),
                  label: Text(widget.controlsLabel),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
