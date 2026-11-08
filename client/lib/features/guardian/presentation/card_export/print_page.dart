import 'dart:math' as math;

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

  /// 카드 한 장 이미지 (앱 카드 333×410 비율 + 아래 띠)
  static const cardImage = Size(333, 440);

  /// 굽는 해상도: A4 300dpi (2480px) · 카드 이미지 긴 변 약 2600px
  static const a4PixelRatio = 2480 / 595;
  static const cardImagePixelRatio = 6.0;
}

/// 인쇄 지면 한 장: 흰 종이 + 내용 + 아래 띠(로고·출처) + Free 워터마크
///
/// 시스템 글자 크기를 따르지 않는다 — 종이에 찍히는 크기가 기기마다 달라지면 칸이 넘친다.
class PrintPage extends StatelessWidget {
  const PrintPage({
    super.key,
    required this.size,
    required this.child,
    required this.hasWatermark,
    required this.shouldShowPictogramCredit,
    this.shouldShowEmojiCredit = false,
    this.margin = 24,
  });

  final Size size;
  final Widget child;

  /// Free: 이룸 로고 띠 + 바탕 워터마크 (카드 그림·문장은 덮지 않음)
  final bool hasWatermark;

  /// Mulberry 픽토그램을 쓴 지면은 출처를 적는다 (CC BY-SA 4.0 조건)
  final bool shouldShowPictogramCredit;

  /// Twemoji 이모지를 쓴 지면은 출처를 적는다 (CC BY 4.0 조건, #1149)
  final bool shouldShowEmojiCredit;

  /// 종이 가장자리 여백 (프린터가 못 찍는 자리 포함)
  final double margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasFooter = hasWatermark || shouldShowPictogramCredit || shouldShowEmojiCredit;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox.fromSize(
        size: size,
        child: ColoredBox(
          color: colors.surface,
          child: Stack(
            children: [
              // 워터마크는 맨 아래 층 — 카드가 불투명이라 카드 사이·여백에만 보인다
              if (hasWatermark) const Positioned.fill(child: _WatermarkPattern()),
              Padding(
                padding: EdgeInsets.all(margin),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: child),
                    if (hasFooter) ...[
                      const SizedBox(height: 8),
                      _Footer(
                        hasWatermark: hasWatermark,
                        shouldShowPictogramCredit: shouldShowPictogramCredit,
                        shouldShowEmojiCredit: shouldShowEmojiCredit,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 아래 띠: (Free) 이룸 로고 + 문구 · (그림 기호·이모지) 그림 출처
class _Footer extends StatelessWidget {
  const _Footer({
    required this.hasWatermark,
    required this.shouldShowPictogramCredit,
    required this.shouldShowEmojiCredit,
  });

  final bool hasWatermark;
  final bool shouldShowPictogramCredit;
  final bool shouldShowEmojiCredit;

  /// 로고 높이 (포인트, 카드 한 장 이미지 폭 333 에서도 띠 한 줄에 들어가는 크기)
  static const _logoHeight = 24.0;

  /// 출처 글이 차지할 몫 (Spacer 1 대비, 로고 띠보다 넓게)
  static const _creditFlex = 4;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.printFooter.copyWith(color: context.colors.textSecondary);
    return Row(
      children: [
        if (hasWatermark) ...[
          SvgPicture.asset(AppAssets.logo, height: _logoHeight),
          const SizedBox(width: 8),
          Text(context.l10n.cardExportFooterMadeWith, style: style),
        ],
        const Spacer(),
        // 출처 둘이면 한 줄에 이어 씀 (카드 이미지 폭이 좁아 넘치면 줄바꿈)
        if (shouldShowPictogramCredit || shouldShowEmojiCredit)
          Flexible(
            flex: _creditFlex,
            child: Text(
              [
                if (shouldShowPictogramCredit) context.l10n.cardExportPictogramCredit,
                if (shouldShowEmojiCredit) context.l10n.cardExportEmojiCredit,
              ].join(' · '),
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
      ],
    );
  }
}

/// 바탕에 비스듬히 깔리는 옅은 `이룸` 글자 무늬
class _WatermarkPattern extends StatelessWidget {
  const _WatermarkPattern();

  /// 글자 사이 간격 (포인트) · 기울기
  static const _spacing = 90.0;
  static const _angle = -math.pi / 6;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.printWatermark.copyWith(
      color: context.colors.textPlaceholder,
    );
    final label = context.l10n.cardExportWatermarkText;
    return IgnorePointer(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / _spacing).ceil() + 2;
            final rows = (constraints.maxHeight / _spacing).ceil() + 2;
            return OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.rotate(
                angle: _angle,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var row = 0; row < rows; row++)
                      SizedBox(
                        height: _spacing,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var column = 0; column < columns; column++)
                              SizedBox(
                                width: _spacing,
                                child: Center(child: Text(label, style: style)),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
