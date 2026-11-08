import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/pro_teaser.dart';
import '../../../../core/widgets/pro_upsell_button.dart';
import 'print_sheets.dart';

/// 인쇄용으로 받기: Free 가 잠긴 값(형태·배치·디자인)을 고르면 그 값으로 만든 첫 지면을 Pro 미리 보기로 보여 줌
///
/// 굽는 미리 보기(RepaintBoundary)와 따로 그린다 — 보내기·인쇄는 언제나 고를 수 있는 값으로만 나감
class CardExportProTeaser extends StatelessWidget {
  const CardExportProTeaser({
    super.key,
    required this.sheet,
    required this.title,
    required this.benefit,
    required this.actions,
  });

  /// 잠긴 값으로 만든 첫 지면 (내 일과 카드 그대로)
  final PrintSheet sheet;

  /// 기능별 제목 · 한 줄 (형태·배치 / 디자인)
  final String title;
  final String benefit;

  /// 버튼 문구(체험 기간) · 요금제 화면 열기
  final ProUpsellActions actions;

  @override
  Widget build(BuildContext context) {
    return ProTeaser(
      title: title,
      benefit: benefit,
      actions: actions,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: context.colors.border)),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox.fromSize(size: sheet.size, child: sheet.page),
        ),
      ),
    );
  }
}
