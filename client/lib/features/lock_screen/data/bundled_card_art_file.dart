import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/example_card_image/example_card_image_catalog.dart';
import '../../../shared/pictogram/pictogram_catalog.dart';
import '../../../shared/pictogram/pictogram_svg_loader.dart';

/// 올린 그림이 없는 카드의 번들 그림 > 위젯이 읽을 파일 (#1465)
/// 예시 그림(webp)은 그대로 복사, 픽토그램(SVG)은 흰 바탕 PNG 로 그림 (모양·색은 바꾸지 않음, 라이선스)
/// 위젯(iOS 확장 · Android RemoteViews)은 앱 번들 자산과 SVG 를 직접 못 읽음. 실패하면 null (위젯은 루미 그림으로 대신)
class BundledCardArtFile {
  // 픽토그램 PNG 한 변 · 둘레 여백 (512 기준 40, 앱 카드 그림칸과 비슷한 여백) · 흰 바탕은 색 토큰
  static const _pictogramPixelSide = 512;
  static const _pictogramPaddingPixels = 40.0;
  static const _directoryName = 'widget_card_art';

  /// 예시 그림 > 픽토그램 순서로 파일 경로 (둘 다 없으면 null)
  Future<String?> filePathOf({String? exampleImageId, String? pictogramId}) async {
    try {
      final example = ExampleCardImageCatalog.parse(exampleImageId);
      if (example != null) return await _copyExampleImage(example);
      final pictogram = PictogramCatalog.parse(pictogramId);
      if (pictogram != null) return await _renderPictogram(pictogram);
    } catch (error, stackTrace) {
      AppLogger.error('[widget card art] file failed', error, stackTrace, {
        'exampleImageId': exampleImageId ?? '',
        'pictogramId': pictogramId ?? '',
      });
    }
    return null;
  }

  Future<String> _copyExampleImage(String id) async {
    final file = await _fileFor('example_$id.webp');
    if (await file.exists()) return file.path;
    final data = await rootBundle.load(AppAssets.exampleRoutineImage(id));
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }

  // 픽토그램 SVG > 흰 바탕 정사각 PNG (가운데 · 비율 유지)
  Future<String> _renderPictogram(String id) async {
    final file = await _fileFor('pictogram_$id.png');
    if (await file.exists()) return file.path;
    final pictureInfo = await vg.loadPicture(PictogramSvgLoader(id), null);
    final side = _pictogramPixelSide.toDouble();
    final inner = side - _pictogramPaddingPixels * 2;
    final source = pictureInfo.size;
    final scale = (source.width <= 0 || source.height <= 0)
        ? 1.0
        : (inner / source.width < inner / source.height ? inner / source.width : inner / source.height);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawRect(Rect.fromLTWH(0, 0, side, side), Paint()..color = AppColors.light.surface)
      ..translate((side - source.width * scale) / 2, (side - source.height * scale) / 2)
      ..scale(scale);
    canvas.drawPicture(pictureInfo.picture);
    pictureInfo.picture.dispose();
    final image = await recorder.endRecording().toImage(_pictogramPixelSide, _pictogramPixelSide);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) throw StateError('pictogram png encode failed');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file.path;
  }

  // 저장 위치: {앱 지원 폴더}/widget_card_art/{이름}
  Future<File> _fileFor(String name) async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory('${support.path}/$_directoryName');
    if (!await directory.exists()) await directory.create(recursive: true);
    return File('${directory.path}/$name');
  }
}

final bundledCardArtFileProvider = Provider<BundledCardArtFile>((ref) => BundledCardArtFile());
