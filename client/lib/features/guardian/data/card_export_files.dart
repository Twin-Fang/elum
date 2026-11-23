import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app_settings/app_settings.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../../core/logger/app_logger.dart';

/// 카드 저장 실패 코드 (화면 에러 코드로 보임)
abstract final class CardExportErrorCode {
  static const image = 'E-EXPORT-IMAGE';
  static const render = 'E-EXPORT-RENDER';
  static const save = 'E-EXPORT-SAVE';
  static const saveDenied = 'E-EXPORT-SAVE-DENIED';
}

/// 사진 앱 저장 결과 3개: 저장함 · 권한 거부(설정 안내) · 그 밖의 실패(용량 등)
enum CardSaveOutcome { saved, permissionDenied, failed }

/// 내보내기 파일: 지면 굽기 > PNG > 사진 앱(카드 저장, #1461) · PDF > 공유 시트(주간 리포트 · AI 메모)
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

  /// A4 PNG 여러 장 > PDF (쪽마다 그림 한 장을 꽉 채움 · 여백은 지면이 이미 들고 있음). [isLandscape] 면 A4 가로
  Future<Uint8List> buildA4Pdf(List<Uint8List> pagePngs, {bool isLandscape = false}) async {
    final document = pw.Document();
    final pageFormat = isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    for (final png in pagePngs) {
      final image = pw.MemoryImage(png);
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Image(image, fit: pw.BoxFit.fill),
        ),
      );
    }
    return document.save();
  }

  /// 공유 시트 (파일은 임시 폴더에: `{이름}.pdf` · `{이름}.png` · `{이름}.json`)
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

  /// PNG 여러 장 > 사진 앱 (권한 확인 > 차례로 저장, 이름 `{이름}_01`)
  ///
  /// 권한은 사진 추가만 (iOS add-only · Android 10 이상은 묻지 않음)
  Future<CardSaveOutcome> saveToPhotos({required List<Uint8List> pngs, required String fileStem}) async {
    try {
      final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
      if (!hasAccess) return CardSaveOutcome.permissionDenied;
      for (final (index, png) in pngs.indexed) {
        await Gal.putImageBytes(png, name: '${fileStem}_${(index + 1).toString().padLeft(2, '0')}');
      }
      return CardSaveOutcome.saved;
    } on GalException catch (error) {
      AppLogger.error('card export save failed', error);
      return error.type == GalExceptionType.accessDenied ? CardSaveOutcome.permissionDenied : CardSaveOutcome.failed;
    }
  }

  /// 기기 설정의 이 앱 화면 (사진 추가 권한을 다시 켜는 길)
  Future<void> openAppSettings() async {
    try {
      await AppSettings.openAppSettings();
    } on Object catch (error) {
      AppLogger.error('card export open settings failed', error);
    }
  }
}

/// 파일 이름에 못 쓰는 글자 정리 (`/ \ : * ? " < > |` > `_`, 빈 이름은 `elum`)
String exportFileStem(String title) {
  final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_').trim();
  if (cleaned.isEmpty || cleaned == '_') return 'elum';
  return cleaned.length > 40 ? cleaned.substring(0, 40) : cleaned;
}
