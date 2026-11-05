import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Flat, friendly illustrations drawn for Cash Buddy (inline SVG, so they
/// work offline and recolour themselves to the current theme).
enum Art { welcome, growth, inbox, handshake, piggy, receipt }

class _Pal {
  final String p, pl, a, g, v, ink, skin, hair, paper, y;
  const _Pal(
    this.p,
    this.pl,
    this.a,
    this.g,
    this.v,
    this.ink,
    this.skin,
    this.hair,
    this.paper,
    this.y,
  );
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Floating, gently bobbing illustration.
class Illustration extends StatefulWidget {
  final Art art;
  final double height;
  final bool animate;
  const Illustration(
    this.art, {
    super.key,
    this.height = 180,
    this.animate = true,
  });
  @override
  State<Illustration> createState() => _IllustrationState();
}

class _IllustrationState extends State<Illustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final dark = s.brightness == Brightness.dark;
    final pal = _Pal(
      _hex(s.primary),
      _hex(
        Color.alphaBlend(
          s.primary.withValues(alpha: dark ? 0.22 : 0.14),
          s.surface,
        ),
      ),
      '#FF8A3D',
      '#22B573',
      '#8B5CF6',
      dark ? '#E7EAF6' : '#2B2F4A',
      '#F2B48D',
      dark ? '#C9CCE3' : '#2B2F4A',
      dark ? '#2A3144' : '#FFFFFF',
      '#FFC83D',
    );
    final svg = _build(widget.art, pal);
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) => Transform.translate(
            offset: Offset(0, math.sin(_c.value * 2 * math.pi) * 4),
            child: child,
          ),
          child: SvgPicture.string(svg, height: widget.height),
        ),
      ),
    );
  }
}

String _build(Art a, _Pal c) {
  final body = switch (a) {
    Art.welcome => _welcome(c),
    Art.growth => _growth(c),
    Art.inbox => _inbox(c),
    Art.handshake => _handshake(c),
    Art.piggy => _piggy(c),
    Art.receipt => _receipt(c),
  };
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 300">'
      '<ellipse cx="200" cy="278" rx="130" ry="10" fill="${c.ink}" opacity="0.08"/>'
      '$body</svg>';
}

String _blob(_Pal c) =>
    '<path d="M70 150C60 90 120 40 200 44s140 36 140 100-30 120-140 120S80 210 70 150Z" fill="${c.pl}"/>';

String _coin(double x, double y, double r, _Pal c) =>
    '<circle cx="$x" cy="$y" r="$r" fill="${c.y}"/>'
    '<circle cx="$x" cy="$y" r="${r * 0.68}" fill="none" stroke="#E5A100" stroke-width="${r * 0.14}"/>'
    '<rect x="${x - r * 0.1}" y="${y - r * 0.36}" width="${r * 0.2}" height="${r * 0.72}" rx="${r * 0.1}" fill="#E5A100"/>';

String _spark(double x, double y, double s, String col) =>
    '<path d="M$x ${y - s}L${x + s * .28} ${y - s * .28}L${x + s} $y L${x + s * .28} ${y + s * .28}L$x ${y + s}L${x - s * .28} ${y + s * .28}L${x - s} $y L${x - s * .28} ${y - s * .28}Z" fill="$col"/>';

String _leaf(double x, double y, double rot, String col) =>
    '<path transform="translate($x $y) rotate($rot)" d="M0 0C-16 -10 -16 -34 0 -46 16 -34 16 -10 0 0Z" fill="$col"/>';

String _person(double x, double y, String shirt, _Pal c, {double s = 1}) =>
    '<g transform="translate($x $y) scale($s)">'
    '<rect x="-24" y="30" width="48" height="62" rx="20" fill="$shirt"/>'
    '<rect x="-9" y="18" width="18" height="18" rx="6" fill="${c.skin}"/>'
    '<circle cx="0" cy="0" r="23" fill="${c.skin}"/>'
    '<path d="M-24 -4C-26 -30 -4 -34 8 -30S28 -20 24 -2C16 -14 -8 -16 -24 -4Z" fill="${c.hair}"/>'
    '<circle cx="-8" cy="3" r="2.2" fill="${c.ink}"/><circle cx="8" cy="3" r="2.2" fill="${c.ink}"/>'
    '<path d="M-6 12Q0 17 6 12" fill="none" stroke="${c.ink}" stroke-width="2" stroke-linecap="round"/>'
    '</g>';

String _welcome(_Pal c) =>
    '${_blob(c)}'
    '<rect x="108" y="112" width="184" height="130" rx="26" fill="${c.p}"/>'
    '<path d="M108 140a26 26 0 0 1 26-26h132a26 26 0 0 1 26 26v8H108Z" fill="${c.v}" opacity="0.55"/>'
    '<rect x="236" y="158" width="72" height="42" rx="20" fill="${c.paper}"/>'
    '<circle cx="256" cy="179" r="8" fill="${c.a}"/>'
    '<rect x="128" y="90" width="132" height="40" rx="10" fill="${c.g}" transform="rotate(-8 128 90)"/>'
    '<rect x="150" y="84" width="132" height="40" rx="10" fill="#34D399" transform="rotate(5 150 84)"/>'
    '${_coin(96, 96, 22, c)}${_coin(316, 78, 17, c)}${_coin(330, 210, 14, c)}'
    '${_spark(70, 190, 10, c.a)}${_spark(342, 140, 8, c.v)}${_spark(180, 54, 7, c.y)}'
    '${_leaf(104, 246, -20, c.g)}${_leaf(118, 246, 18, "#16A06A")}';

String _growth(_Pal c) =>
    '${_blob(c)}'
    '<rect x="96" y="176" width="40" height="68" rx="10" fill="${c.pl}" stroke="${c.p}" stroke-width="3"/>'
    '<rect x="150" y="146" width="40" height="98" rx="10" fill="${c.p}" opacity="0.7"/>'
    '<rect x="204" y="112" width="40" height="132" rx="10" fill="${c.p}" opacity="0.85"/>'
    '<rect x="258" y="70" width="40" height="174" rx="10" fill="${c.p}"/>'
    '<path d="M104 160C150 150 190 110 250 74" fill="none" stroke="${c.a}" stroke-width="6" stroke-linecap="round" stroke-dasharray="2 12"/>'
    '<path d="M240 66l22 2-8 20Z" fill="${c.a}"/>'
    '${_coin(278, 50, 20, c)}${_coin(118, 128, 15, c)}'
    '${_leaf(320, 244, 12, c.g)}${_leaf(334, 244, -24, "#16A06A")}${_leaf(326, 214, 0, c.g)}'
    '${_spark(76, 96, 10, c.v)}${_spark(330, 110, 8, c.a)}';

String _inbox(_Pal c) =>
    '${_blob(c)}'
    '<rect x="140" y="52" width="130" height="200" rx="24" fill="${c.ink}"/>'
    '<rect x="150" y="66" width="110" height="172" rx="14" fill="${c.paper}"/>'
    '<rect x="176" y="58" width="58" height="6" rx="3" fill="${c.paper}" opacity="0.4"/>'
    '<rect x="162" y="84" width="72" height="30" rx="12" fill="${c.pl}"/>'
    '<rect x="176" y="124" width="72" height="30" rx="12" fill="${c.p}"/>'
    '<rect x="162" y="164" width="60" height="30" rx="12" fill="${c.pl}"/>'
    '<rect x="172" y="94" width="40" height="5" rx="2.5" fill="${c.p}"/>'
    '<rect x="188" y="134" width="44" height="5" rx="2.5" fill="${c.paper}"/>'
    '<circle cx="268" cy="104" r="26" fill="${c.g}"/>'
    '<path d="M256 104l9 9 17-19" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
    '${_coin(112, 150, 16, c)}${_spark(100, 80, 9, c.a)}${_spark(314, 192, 9, c.v)}';

String _handshake(_Pal c) =>
    '${_blob(c)}'
    '${_person(142, 96, c.p, c)}${_person(262, 96, c.a, c, s: 1)}'
    '<path d="M170 196h60" stroke="${c.ink}" stroke-width="5" stroke-linecap="round" stroke-dasharray="2 10"/>'
    '<path d="M222 186l16 10-16 10Z" fill="${c.ink}"/>'
    '${_coin(200, 160, 22, c)}'
    '${_spark(84, 84, 9, c.v)}${_spark(320, 60, 8, c.g)}';

String _piggy(_Pal c) =>
    '${_blob(c)}'
    '<ellipse cx="200" cy="180" rx="92" ry="66" fill="#FF9EC0"/>'
    '<path d="M150 128l-14-30 34 14Z" fill="#FF7FAD"/><path d="M236 124l16-30-36 12Z" fill="#FF7FAD"/>'
    '<ellipse cx="282" cy="184" rx="22" ry="17" fill="#FF7FAD"/>'
    '<circle cx="276" cy="184" r="3.5" fill="#B83B6E"/><circle cx="290" cy="184" r="3.5" fill="#B83B6E"/>'
    '<circle cx="250" cy="160" r="6" fill="${c.ink}"/>'
    '<rect x="176" y="118" width="48" height="9" rx="4.5" fill="#B83B6E"/>'
    '<rect x="146" y="226" width="24" height="34" rx="10" fill="#FF7FAD"/><rect x="232" y="226" width="24" height="34" rx="10" fill="#FF7FAD"/>'
    '${_coin(200, 78, 24, c)}${_coin(300, 96, 13, c)}${_coin(104, 120, 12, c)}'
    '${_spark(84, 200, 9, c.v)}${_spark(330, 150, 8, c.g)}';

String _receipt(_Pal c) =>
    '${_blob(c)}'
    '<path d="M132 52h136v196l-17-12-17 12-17-12-17 12-17-12-17 12-17-12Z" fill="${c.paper}" stroke="${c.p}" stroke-width="4" stroke-linejoin="round"/>'
    '<rect x="152" y="76" width="64" height="9" rx="4.5" fill="${c.p}"/>'
    '<rect x="152" y="104" width="96" height="7" rx="3.5" fill="${c.pl}"/>'
    '<rect x="152" y="124" width="80" height="7" rx="3.5" fill="${c.pl}"/>'
    '<rect x="152" y="144" width="90" height="7" rx="3.5" fill="${c.pl}"/>'
    '<rect x="152" y="178" width="96" height="12" rx="6" fill="${c.g}" opacity="0.85"/>'
    '<circle cx="284" cy="182" r="32" fill="${c.pl}" stroke="${c.a}" stroke-width="8"/>'
    '<path d="M308 206l30 30" stroke="${c.a}" stroke-width="12" stroke-linecap="round"/>'
    '${_spark(100, 100, 10, c.a)}${_spark(330, 84, 9, c.v)}${_coin(108, 206, 14, c)}';
