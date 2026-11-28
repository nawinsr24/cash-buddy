import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../l10n/l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'group_keeper.dart';

const _prefix = 'cashpp:';

/// The invite code inside a scanned QR, or null if it is some other QR.
String? codeFromQr(String? raw) {
  if (raw == null || !raw.startsWith(_prefix)) return null;
  final code = raw.substring(_prefix.length);
  return RegExp(r'^[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{40,}$').hasMatch(code)
      ? code
      : null;
}

/// Opens the camera and returns a code; null when the user backs out, and an
/// empty string when they want to type it instead. Replaceable in tests.
final scanCodeProvider = Provider<Future<String?> Function(BuildContext)>(
  (ref) =>
      (context) => Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => const ScanCodePage())),
);

/// Show this to your partner.
class ShowCodePage extends StatefulWidget {
  final String code;

  /// The partner's name once they have joined, else null.
  final Future<String?> Function() partner;
  const ShowCodePage({super.key, required this.code, required this.partner});

  @override
  State<ShowCodePage> createState() => _ShowCodePageState();
}

class _ShowCodePageState extends State<ShowCodePage> {
  String? _joined;

  @override
  void initState() {
    super.initState();
    groupSynced.addListener(_look);
    _look();
  }

  @override
  void dispose() {
    groupSynced.removeListener(_look);
    super.dispose();
  }

  Future<void> _look() async {
    final name = await widget.partner();
    if (mounted && name != null && _joined == null) {
      haptic();
      setState(() => _joined = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = _joined;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Invite your partner'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Sp.x5),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, a) => ScaleTransition(
                scale: a,
                child: FadeTransition(opacity: a, child: child),
              ),
              child: joined == null ? _code(context) : _done(context, joined),
            ),
          ),
        ),
      ),
    );
  }

  Widget _code(BuildContext context) => Column(
    key: const ValueKey('code'),
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(Sp.x2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF17B03), Color(0xFFF3AD3D)],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(Sp.x5),
          // a QR needs a light background in either theme
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: SizedBox.square(
            dimension: 232,
            child: QrImageView(
              data: '$_prefix${widget.code}',
              padding: EdgeInsets.zero,
              // spare detail, so round dots still scan easily
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: Color(0xFF2A1D6B),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF2A1D6B),
              ),
              semanticsLabel: tr('Invite QR code'),
            ),
          ),
        ),
      ),
      const SizedBox(height: Sp.x5),
      Text(
        tr('Ask your partner to scan this'),
        textAlign: TextAlign.center,
        style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: Sp.x2),
      Text(
        tr('Valid for one day. Anyone who scans it can join your home.'),
        textAlign: TextAlign.center,
        style: TextStyle(color: context.cash.textMuted),
      ),
      const SizedBox(height: Sp.x5),
      const LinearProgressIndicator(),
      const SizedBox(height: Sp.x2),
      Text(
        tr('Waiting for your partner'),
        style: TextStyle(color: context.cash.textMuted),
      ),
      const SizedBox(height: Sp.x3),
      TextButton.icon(
        icon: const Icon(Icons.copy, size: 18),
        label: Text(tr('Copy code instead')),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: widget.code));
          if (context.mounted) toast(context, 'Copied');
        },
      ),
    ],
  );

  Widget _done(BuildContext context, String name) => Column(
    key: const ValueKey('done'),
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 56,
        backgroundColor: context.cash.income.withValues(alpha: 0.16),
        child: Icon(Icons.check_rounded, size: 64, color: context.cash.income),
      ),
      const SizedBox(height: Sp.x5),
      Text(
        '$name ${tr('joined your home')}',
        textAlign: TextAlign.center,
        style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: Sp.x5),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: Text(tr('Done')),
      ),
    ],
  );
}

/// Point the camera at the partner's QR.
class ScanCodePage extends StatefulWidget {
  const ScanCodePage({super.key});
  @override
  State<ScanCodePage> createState() => _ScanCodePageState();
}

class _ScanCodePageState extends State<ScanCodePage> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  var _found = false;

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  void _seen(BarcodeCapture capture) {
    if (_found) return;
    for (final b in capture.barcodes) {
      final code = codeFromQr(b.rawValue);
      if (code == null) continue;
      _found = true;
      haptic();
      Navigator.pop(context, code);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    const white = Colors.white;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: white,
        title: Text(tr('Scan partner\'s QR')),
        actions: [
          IconButton(
            tooltip: tr('Torch'),
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _camera.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _seen,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(Sp.x5),
                child: Text(
                  tr('The camera is not available. Type the code instead.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: white),
                ),
              ),
            ),
          ),
          // dim everything but the square to aim with
          IgnorePointer(child: CustomPaint(painter: _Frame())),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(Sp.x5),
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: white),
                  onPressed: () => Navigator.pop(context, ''),
                  child: Text(tr('Type the code instead')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Frame extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.68;
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: side,
        height: side,
      ),
      const Radius.circular(28),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(hole),
      Paint()..color = const Color(0x99000000),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_Frame old) => false;
}
