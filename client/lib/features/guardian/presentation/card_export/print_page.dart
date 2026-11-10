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
  static const cardImage = Size(printCardWidth, printCardHeight + _cardImageFooterHeight);

  /// 카드 한 장 이미지의 아래 띠 자리 (로고·출처 한 줄)
  static const _cardImageFooterHeight = 30.0;

  /// 굽는 해상도: A4 300dpi (2480px) · 카드 이미지 긴 변 약 2600px
  static const a4PixelRatio = 2480 / 595;
  static const cardImagePixelRatio = 6.0;
}

/// 인쇄 지면 한 장: 흰 종이 + 내용 + 아래 띠(Free 는 로고·소개 글, 그림 출처)
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

  /// Free: 아래 띠에 이룸 로고 + 소개 글 (Pro 는 없음)
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
          child: Padding(
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
        ),
      ),
    );
  }
}

/// 아래 띠: (Free) 왼쪽 이룸 로고 + 오른쪽 소개 글 한 줄, (그림 기호·이모지) 그 아래 줄에 그림 출처
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

  /// 띠 줄 > 출처 줄 사이
  static const _creditTopGap = 2.0;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.printFooter.copyWith(color: context.colors.textSecondary);
    final hasCredit = shouldShowPictogramCredit || shouldShowEmojiCredit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasWatermark)
          Row(
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
          ),
        // 출처 둘이면 한 줄에 이어 쓰고, 좁으면 글자를 줄여 한 줄을 지킨다
        if (hasCredit) ...[
          if (hasWatermark) const SizedBox(height: _creditTopGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              [
                if (shouldShowPictogramCredit) context.l10n.cardExportPictogramCredit,
                if (shouldShowEmojiCredit) context.l10n.cardExportEmojiCredit,
              ].join(' · '),
              maxLines: 1,
              style: style,
            ),
          ),
        ],
      ],
    );
  }
}
