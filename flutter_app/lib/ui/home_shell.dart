import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'moodboard/moodboard_page.dart';
import 'palette/palette_page.dart';
import 'responsive.dart';

enum AppTab { palette, moodboard }

const Map<AppTab, ({String label, IconData icon})> _tabs = <AppTab, ({String label, IconData icon})>{
  AppTab.palette: (label: 'Palette', icon: Icons.palette_outlined),
  AppTab.moodboard: (label: 'Mood Board', icon: Icons.dashboard_outlined),
};

/// Top-level navigation: bottom bar (narrow), rail (medium), top tabs (wide).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.palette;

  Widget get _body => IndexedStack(
        index: _tab.index,
        children: const <Widget>[PalettePage(), MoodBoardPage()],
      );

  void _select(int index) => setState(() => _tab = AppTab.values[index]);

  @override
  Widget build(BuildContext context) {
    final FormFactor factor = formFactorForWidth(MediaQuery.sizeOf(context).width);

    switch (factor) {
      case FormFactor.narrow:
        return Scaffold(
          appBar: AppBar(title: const _Title(), toolbarHeight: 56),
          body: SafeArea(child: _body),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: _select,
            destinations: <Widget>[
              for (final AppTab t in AppTab.values)
                NavigationDestination(icon: Icon(_tabs[t]!.icon), label: _tabs[t]!.label),
            ],
          ),
        );
      case FormFactor.medium:
        return Scaffold(
          appBar: AppBar(title: const _Title()),
          body: SafeArea(
            child: Row(
              children: <Widget>[
                NavigationRail(
                  selectedIndex: _tab.index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  destinations: <NavigationRailDestination>[
                    for (final AppTab t in AppTab.values)
                      NavigationRailDestination(
                        icon: Icon(_tabs[t]!.icon),
                        label: Text(_tabs[t]!.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _body),
              ],
            ),
          ),
        );
      case FormFactor.wide:
        return Scaffold(
          appBar: AppBar(
            title: const _Title(),
            actions: <Widget>[
              SegmentedButton<AppTab>(
                segments: <ButtonSegment<AppTab>>[
                  for (final AppTab t in AppTab.values)
                    ButtonSegment<AppTab>(
                      value: t,
                      icon: Icon(_tabs[t]!.icon),
                      label: Text(_tabs[t]!.label),
                    ),
                ],
                selected: <AppTab>{_tab},
                onSelectionChanged: (Set<AppTab> s) => _select(s.first.index),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: SafeArea(child: _body),
        );
    }
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Image.asset('assets/icons/color-palette.png', width: 28, height: 28,
            semanticLabel: 'Palette logo'),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'Palette & MoodBoard',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate200),
          ),
        ),
      ],
    );
  }
}
