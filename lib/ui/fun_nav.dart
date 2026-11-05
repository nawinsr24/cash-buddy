import 'package:flutter/material.dart';

import 'motion.dart';
import 'theme.dart';

class FunNavItem {
  final IconData icon, selectedIcon;
  final String label;
  final int badge;
  const FunNavItem(this.icon, this.selectedIcon, this.label, {this.badge = 0});
}

/// A floating bottom bar with a liquid pill that slides (and slightly
/// overshoots) to the chosen tab, while that tab's icon bounces.
class FunNavBar extends StatelessWidget {
  final int index;
  final List<FunNavItem> items;
  final ValueChanged<int> onTap;
  const FunNavBar({
    super.key,
    required this.index,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.scheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.x3, 0, Sp.x3, Sp.x2),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: context.cash.surfaceRaised,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: context.scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.4 : 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth / items.length;
              return Stack(
                children: [
                  // the liquid pill
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 460),
                    curve: Curves.easeOutBack,
                    left: index * w + 6,
                    top: 8,
                    width: w - 12,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: dark ? 0.22 : 0.12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _Item(
                            item: items[i],
                            selected: i == index,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final FunNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _Item({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.scheme.primary;
    final muted = context.cash.textMuted;
    final icon = Icon(
      selected ? item.selectedIcon : item.icon,
      size: 25,
      color: selected ? accent : muted,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Pressable(
        onTap: onTap,
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // bounce each time this tab becomes the selected one
              TweenAnimationBuilder<double>(
                key: ValueKey(selected),
                tween: Tween(begin: selected ? 0.6 : 1, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (_, t, c) => Transform.scale(scale: t, child: c),
                child: item.badge > 0
                    ? Badge(label: Text('${item.badge}'), child: icon)
                    : icon,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? accent : muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
