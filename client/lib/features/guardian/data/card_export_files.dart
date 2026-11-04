import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// 내보내기 실패 코드 (화면 에러 코드로 보임)
abstract final class CardExportErrorCode {
  static const image = 'E-EXPORT-IMAGE';
  static const render = 'E-EXPORT-RENDER';
  static const print = 'E-EXPORT-PRINT';
}

/// 내보내기 파일 만들기: 미리 보기 지면 굽기 > PNG · PDF > 공유 시트 · 인쇄 화면
class CardExportFiles {
  const CardExportFiles();

  /// 그려진 지면 하나 > PNG 바이트 (지면 논리 크기 × [pixelRatio])
  Future<Uint8List> capturePng(RenderRepaintBoundary boundary, double pixelRatio) async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('png encode returned null');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// A4 PNG 여러 장 > PDF (쪽마다 그림 한 장을 꽉 채움 · 여백은 지면이 이미 들고 있음)
  Future<Uint8List> buildA4Pdf(List<Uint8List> pagePngs) async {
    final document = pw.Document();
    for (final png in pagePngs) {
      final image = pw.MemoryImage(png);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }
    return document.save();
  }

  /// 공유 시트 (파일은 임시 폴더에: `{이름}.pdf` · `{이름}_01.png`)
  Future<void> share({
    required List<({String fileName, Uint8List bytes, String mimeType})> files,
    ui.Rect? sharePositionOrigin,
  }) async {
    final directory = await getTemporaryDirectory();
    final shared = <XFile>[];
    for (final file in files) {
      final path = '${directory.path}/${file.fileName}';
      await File(path).writeAsBytes(file.bytes, flush: true);
      shared.add(XFile(path, mimeType: file.mimeType, name: file.fileName));
    }
    await SharePlus.instance.share(
      ShareParams(files: shared, sharePositionOrigin: sharePositionOrigin),
    );
  }

  /// 기기 인쇄 화면 (iOS AirPrint · Android 인쇄 서비스). 인쇄할 수 없는 기기면 false
  Future<bool> printPdf({required Uint8List pdf, required String jobName}) async {
    final info = await Printing.info();
    if (!info.canPrint) return false;
    return Printing.layoutPdf(
      name: jobName,
      format: PdfPageFormat.a4,
      // 실제 크기로 찍게 A4 그대로 넘김 (용지에 맞춤 축소를 막아 오려 쓰는 카드 크기 유지)
      usePrinterSettings: false,
      onLayout: (_) async => pdf,
    );
  }
}

/// 파일 이름에 못 쓰는 글자 정리 (`/ \ : * ? " < > |` > `_`, 빈 이름은 `elum`)
String exportFileStem(String title) {
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_').trim();
  if (cleaned.isEmpty || cleaned == '_') return 'elum';
  return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
}
