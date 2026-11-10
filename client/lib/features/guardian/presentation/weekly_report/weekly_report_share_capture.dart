import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/card_export_files.dart';
import '../../domain/weekly_report.dart';
import '../card_export/print_page.dart';
import 'weekly_report_share_page.dart';

/// 한 주 한 장(A4)을 화면 밖 오버레이에 그려 PNG 로 굽기 (화면에는 미리 보기를 두지 않음)
///
/// 화면 왼쪽 밖에 놓아 보이지 않고, 굽고 나면 바로 걷는다 (성공·실패 공통)
Future<Uint8List> captureWeeklyReportPng({
  required BuildContext context,
  required WeeklyReport report,
  required String elumiName,
  required bool hasWatermark,
  CardExportFiles files = const CardExportFiles(),
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final boundaryKey = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -(PrintPageSize.a4.width * 2),
      top: 0,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(
            key: boundaryKey,
            child: WeeklyReportSharePage(
              report: report,
              elumiName: elumiName,
              hasWatermark: hasWatermark,
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // 오버레이가 그려질 때까지 한 프레임 기다림
    await WidgetsBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) throw StateError('weekly report page not painted');
    return await files.capturePng(boundary, PrintPageSize.a4PixelRatio);
  } finally {
    entry.remove();
  }
}
