import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 인쇄 지면 크기 (포인트). A4 = 595 × 842
abstract final class PrintPageSize {
  static const a4 = Size(595, 842);

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
    required this.showsPictogramCredit,
    this.margin = 24,
  });

  final Size size;
  final Widget child;

  /// Free: 이룸 로고 띠 + 바탕 워터마크 (카드 그림·문장은 덮지 않음)
  final bool hasWatermark;

  /// Mulberry 픽토그램을 쓴 지면은 출처를 적는다 (CC BY-SA 4.0 조건)
  final bool showsPictogramCredit;

  /// 종이 가장자리 여백 (프린터가 못 찍는 자리 포함)
  final double margin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasFooter = hasWatermark || showsPictogramCredit;
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
                        showsPictogramCredit: showsPictogramCredit,
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

/// 아래 띠: (Free) 이룸 로고 + 문구 · (픽토그램) 그림 출처
class _Footer extends StatelessWidget {
  const _Footer({required this.hasWatermark, required this.showsPictogramCredit});

  final bool hasWatermark;
  final bool showsPictogramCredit;

  /// 로고 높이 (포인트)
  static const _logoHeight = 16.0;

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
        if (showsPictogramCredit)
          Text(context.l10n.cardExportPictogramCredit, style: style),
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
