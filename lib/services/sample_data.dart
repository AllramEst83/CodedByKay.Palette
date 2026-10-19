import 'dart:math' as math;
import 'dart:ui' as ui;

import '../core/color_utils.dart';

class SampleBoardImage {
  const SampleBoardImage(this.image, this.name);

  final ui.Image image;
  final String name;
}

/// Procedurally generated sample images, ported from the legacy `sample-data.js`.
class SampleData {
  const SampleData._();

  static ui.Color _c(String hex) => ui.Color(parseHexColor(hex));

  static Future<ui.Image> sunset() async {
    const double w = 900;
    const double h = 600;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset.zero,
          const ui.Offset(0, h),
          <ui.Color>[_c('#fdba74'), _c('#f43f5e'), _c('#8b5cf6'), _c('#1e1b4b')],
          <double>[0, 0.3, 0.65, 1],
        ),
    );

    canvas.drawCircle(const ui.Offset(450, 320), 110, ui.Paint()..color = _c('#fef08a'));

    canvas.drawPath(
      ui.Path()
        ..moveTo(0, 600)
        ..lineTo(200, 380)
        ..lineTo(400, 520)
        ..lineTo(650, 350)
        ..lineTo(900, 580)
        ..lineTo(900, 600)
        ..close(),
      ui.Paint()..color = _c('#312e81'),
    );

    canvas.drawPath(
      ui.Path()
        ..moveTo(0, 600)
        ..lineTo(150, 480)
        ..lineTo(480, 560)
        ..lineTo(800, 470)
        ..lineTo(900, 600)
        ..close(),
      ui.Paint()..color = _c('#0f172a'),
    );

    return _finish(recorder, w.toInt(), h.toInt());
  }

  static const List<({String c1, String c2, String text})> _boardSamples =
      <({String c1, String c2, String text})>[
    (c1: '#3b82f6', c2: '#1d4ed8', text: 'Azure Motion'),
    (c1: '#ec4899', c2: '#be185d', text: 'Neon Glow'),
    (c1: '#10b981', c2: '#047857', text: 'Botanical'),
    (c1: '#f59e0b', c2: '#b45309', text: 'Amber Dusk'),
    (c1: '#8b5cf6', c2: '#5b21b6', text: 'Velvet Horizon'),
    (c1: '#06b6d4', c2: '#0e7490', text: 'Cyan Tides'),
  ];

  static Future<List<SampleBoardImage>> board() async {
    final List<SampleBoardImage> out = <SampleBoardImage>[];
    for (int i = 0; i < _boardSamples.length; i++) {
      final ({String c1, String c2, String text}) s = _boardSamples[i];
      const double size = 600;
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, size, size),
        ui.Paint()
          ..shader = ui.Gradient.linear(
            ui.Offset.zero,
            const ui.Offset(size, size),
            <ui.Color>[_c(s.c1), _c(s.c2)],
          ),
      );
      canvas.drawCircle(
        ui.Offset(300 + (i.isEven ? 80 : -80), 300),
        180,
        ui.Paint()..color = const ui.Color.fromRGBO(255, 255, 255, 0.15),
      );
      canvas.drawCircle(
        const ui.Offset(300, 300),
        90,
        ui.Paint()..color = const ui.Color.fromRGBO(0, 0, 0, 0.12),
      );

      final ui.ParagraphBuilder builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: ui.TextAlign.center),
      )
        ..pushStyle(ui.TextStyle(
          color: const ui.Color(0xFFFFFFFF),
          fontSize: 32,
          fontWeight: ui.FontWeight.w700,
          fontFamily: 'PlusJakartaSans',
        ))
        ..addText(s.text);
      final ui.Paragraph paragraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: size));
      canvas.drawParagraph(paragraph, ui.Offset(0, 300 - paragraph.height / 2));

      out.add(SampleBoardImage(await _finish(recorder, size.toInt(), size.toInt()), s.text));
    }
    return out;
  }

  static Future<ui.Image> _finish(ui.PictureRecorder recorder, int w, int h) async {
    final ui.Picture picture = recorder.endRecording();
    try {
      return await picture.toImage(math.max(1, w), math.max(1, h));
    } finally {
      picture.dispose();
    }
  }
}
