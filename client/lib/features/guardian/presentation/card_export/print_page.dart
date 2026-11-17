import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/card_export_options.dart';

/// 인쇄 지면 크기 (포인트). A4 세로 595 × 842 · 가로 842 × 595
abstract final class PrintPageSize {
  static const a4 = Size(595, 842);
  static const a4Landscape = Size(842, 595);

  /// 용지 방향 > A4 크기
  static Size a4Of(PaperOrientation orientation) =>
      orientation == PaperOrientation.landscape ? a4Landscape : a4;

  /// 카드 한 장 이미지 (인쇄 카드 + 아래 띠 자리)
  static const cardImage = Size(
    printCardWidth,
    printCardHeight + _cardImageFooterHeight,
  );

  /// 카드 한 장 이미지의 아래 띠 자리 (Free 로고 한 줄)
  static const _cardImageFooterHeight = 30.0;

  /// 굽는 해상도: A4 300dpi (2480px) · 카드 이미지 긴 변 약 2600px
  static const a4PixelRatio = 2480 / 595;
  static const cardImagePixelRatio = 6.0;
}

/// 인쇄 지면 한 장: 흰 종이 + 내용 + 아래 띠(Free 는 로고·소개 글)
/// 그림 출처는 내보낸 이미지에 넣지 않고 앱 안 라이선스 화면에만 둠 (#1446)
///
/// 시스템 글자 크기를 따르지 않는다 — 종이에 찍히는 크기가 기기마다 달라지면 칸이 넘친다.
class PrintPage extends StatelessWidget {
  const PrintPage({
    super.key,
    required this.size,
    required this.child,
    required this.hasWatermark,
    this.margin = 24,
  });

  final Size size;
  final Widget child;

  /// Free: 아래 띠에 이룸 로고 + 소개 글 (Pro 는 없음)
  final bool hasWatermark;

  /// 종이 가장자리 여백 (프린터가 못 찍는 자리 포함)
  final double margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: ColoredBox(
          color: colors.surface,
          child: Padding(
            padding: EdgeInsets.all(margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: child),
                if (hasWatermark) ...[
                  const SizedBox(height: 8),
                  const _Footer(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 아래 띠 (Free): 왼쪽 이룸 로고 + 오른쪽 소개 글 한 줄
class _Footer extends StatelessWidget {
  const _Footer();

  /// 로고 높이 (포인트, 카드 한 장 이미지 폭 333 에서도 띠 한 줄에 들어가는 크기)
  static const _logoHeight = 24.0;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.printFooter.copyWith(
      color: context.colors.textSecondary,
    );
    return Row(
      children: [
        SvgPicture.asset(AppAssets.logo, height: _logoHeight),
        const SizedBox(width: 8),
        // 소개 글은 줄여 쓰지 않고 전부 보인다 (좁으면 줄바꿈)
        Expanded(
          child: Text(
            context.l10n.printBrandTagline,
            textAlign: TextAlign.end,
            style: style,
          ),
        ),
      ],
    );
  }
}
