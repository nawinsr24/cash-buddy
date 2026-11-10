import 'package:flutter/material.dart';

import '../data/db.dart';
import '../ui/emoji.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';

/// Returned by [pickCategory] when the user chooses "no category".
const kNoCategory = '_none';

/// A colourful emoji tile for a category.
class CategoryTile extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final bool selected;
  final bool hasSubs;
  final VoidCallback onTap;
  const CategoryTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.hasSubs = false,
  });

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: () {
      haptic();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.26 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : color.withValues(alpha: 0.18),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.18 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (hasSubs)
            Icon(Icons.more_horiz, size: 14, color: context.cash.textMuted),
        ],
      ),
    ),
  );
}

/// Bottom sheet of emoji tiles: pick a main category, then (if it has any)
/// one of its subcategories. Returns the chosen id, [kNoCategory], or null.
Future<String?> pickCategory(
  BuildContext context, {
  required List<Category> cats,
  String? selectedId,
  bool allowNone = true,
}) => showSheet<String>(
  context,
  (_) => _PickerBody(cats: cats, selectedId: selectedId, allowNone: allowNone),
);

class _PickerBody extends StatefulWidget {
  final List<Category> cats;
  final String? selectedId;
  final bool allowNone;
  const _PickerBody({
    required this.cats,
    required this.selectedId,
    required this.allowNone,
  });
  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  String? focused; // main category whose subcategories are showing

  @override
  void initState() {
    super.initState();
    final sel = widget.cats.where((c) => c.id == widget.selectedId).firstOrNull;
    focused = sel?.parentId;
  }

  List<Category> _subsOf(String id) =>
      widget.cats.where((c) => c.parentId == id).toList();

  @override
  Widget build(BuildContext context) {
    final mains = widget.cats.where((c) => c.parentId == null).toList();
    final focus = mains.where((m) => m.id == focused).firstOrNull;
    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, anim) {
            final entering = child.key == ValueKey(focused);
            return SlideTransition(
              position: Tween(
                begin: Offset(entering && focused != null ? 0.25 : -0.25, 0),
                end: Offset.zero,
              ).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            );
          },
          child: focus == null
              ? _mainView(context, mains)
              : _subView(context, focus),
        ),
      ),
    );
  }

  Widget _mainView(BuildContext context, List<Category> mains) {
    final cols = MediaQuery.sizeOf(context).width >= 600 ? 5 : 3;
    return SingleChildScrollView(
      key: const ValueKey(null),
      padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.x1),
            child: Text(
              'Pick a category',
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: Sp.x3),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: cols,
            mainAxisSpacing: Sp.x2,
            crossAxisSpacing: Sp.x2,
            children: [
              if (widget.allowNone)
                Reveal(
                  child: CategoryTile(
                    emoji: '🏷️',
                    label: tr('No category'),
                    color: context.cash.textMuted,
                    selected: widget.selectedId == null,
                    onTap: () => Navigator.pop(context, kNoCategory),
                  ),
                ),
              for (var i = 0; i < mains.length; i++)
                Reveal(
                  index: i + 1,
                  child: CategoryTile(
                    emoji: emojiForCategory(mains[i].name),
                    label: mains[i].name,
                    color: colorOf(mains[i].colorValue),
                    hasSubs: _subsOf(mains[i].id).isNotEmpty,
                    selected:
                        mains[i].id == widget.selectedId ||
                        _subsOf(mains[i].id)
                            .any((s) => s.id == widget.selectedId),
                    onTap: () {
                      if (_subsOf(mains[i].id).isEmpty) {
                        Navigator.pop(context, mains[i].id);
                      } else {
                        setState(() => focused = mains[i].id);
                      }
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _subView(BuildContext context, Category focus) {
    final color = colorOf(focus.colorValue);
    final subs = _subsOf(focus.id);
    final cols = MediaQuery.sizeOf(context).width >= 600 ? 5 : 3;
    return SingleChildScrollView(
      key: ValueKey(focused),
      padding: const EdgeInsets.fromLTRB(Sp.x4, 0, Sp.x4, Sp.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to categories',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => focused = null),
              ),
              Text(
                emojiForCategory(focus.name),
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: Sp.x2),
              Expanded(
                child: Text(
                  focus.name,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.x2),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Sp.x1),
            child: Eyebrow('Inside'),
          ),
          const SizedBox(height: Sp.x2),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: cols,
            mainAxisSpacing: Sp.x2,
            crossAxisSpacing: Sp.x2,
            children: [
              Reveal(
                child: CategoryTile(
                  emoji: emojiForCategory(focus.name),
                  label: 'Just ${focus.name}',
                  color: color,
                  selected: widget.selectedId == focus.id,
                  onTap: () => Navigator.pop(context, focus.id),
                ),
              ),
              for (var i = 0; i < subs.length; i++)
                Reveal(
                  index: i + 1,
                  child: CategoryTile(
                    emoji: emojiForCategory(subs[i].name, focus.name),
                    label: subs[i].name,
                    color: color,
                    selected: widget.selectedId == subs[i].id,
                    onTap: () => Navigator.pop(context, subs[i].id),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The tappable field that shows the chosen category and opens the picker.
class CategoryField extends StatelessWidget {
  final List<Category> cats;
  final String? categoryId;
  final ValueChanged<String?> onChanged;
  const CategoryField({
    super.key,
    required this.cats,
    required this.categoryId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sel = cats.where((c) => c.id == categoryId).firstOrNull;
    final parent = sel?.parentId == null
        ? null
        : cats.where((c) => c.id == sel!.parentId).firstOrNull;
    final color = sel == null
        ? context.cash.textMuted
        : colorOf(sel.colorValue);
    return Pressable(
      onTap: () async {
        final r = await pickCategory(
          context,
          cats: cats,
          selectedId: categoryId,
        );
        if (r != null) onChanged(r == kNoCategory ? null : r);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x3, vertical: Sp.x3),
        decoration: BoxDecoration(
          color: context.cash.surfaceRaised,
          borderRadius: BorderRadius.circular(Sp.rField),
          border: Border.all(color: context.scheme.outlineVariant),
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (c, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                child: c,
              ),
              child: Container(
                key: ValueKey(categoryId),
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  sel == null
                      ? '🏷️'
                      : emojiForCategory(sel.name, parent?.name),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: Sp.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category',
                    style: context.text.labelSmall?.copyWith(
                      color: context.cash.textMuted,
                    ),
                  ),
                  Text(
                    sel == null
                        ? 'No category'
                        : (parent != null
                              ? '${parent.name} › ${sel.name}'
                              : sel.name),
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }
}
