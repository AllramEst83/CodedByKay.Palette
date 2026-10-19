import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Bordered, rounded card with an optional uppercase header; used by the wide
/// (desktop/web) layout to group the controls and each preview area.
class PanelCard extends StatelessWidget {
  const PanelCard({
    required this.child,
    this.title,
    this.icon,
    this.trailing,
    this.expand = false,
    super.key,
  });

  final Widget child;
  final String? title;
  final IconData? icon;
  final Widget? trailing;

  /// Fill the available height (the parent must give bounded height).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final String? heading = title;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (heading != null) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 18, color: AppColors.slate400),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        heading.toUpperCase(),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
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
            ),
            const Divider(height: 1),
          ],
          if (expand) Expanded(child: child) else child,
        ],
      ),
    );
  }
}
