import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/example_card_image/example_card_art.dart';
import '../../../../shared/models/action_card.dart';
import '../../../../shared/pictogram/pictogram_svg_loader.dart';
import '../../application/card_export_pictures.dart';
import '../../domain/card_export_options.dart';
import '../../domain/card_palette.dart';

/// 인쇄물 카드 한 장: 그림 + (번호) + 제목 (+ 설명). 지면 크기는 부모가 정한다
///
/// 인쇄 지면은 A4 포인트 좌표라 `.w`·`.h` 를 쓰지 않는다 (화면 폭과 무관해야 종이에 같은 크기로 찍힘).
class PrintCard extends StatelessWidget {
  const PrintCard({
    super.key,
    required this.card,
    required this.index,
    required this.picture,
    required this.options,
    required this.language,
    this.showsNumber = true,
    this.showsDescription = false,
  });

  final ActionCard card;

  /// 일과 안 순서 (0부터). 기본 테마 색과 번호가 따른다
  final int index;
  final CardExportPicture picture;
  final CardExportOptions options;

  /// 일과 언어 (카드 문장 글꼴·줄바꿈)
  final String language;

  /// 오려 쓰는 카드는 순서를 바꿔 붙이므로 번호를 뺀다
  final bool showsNumber;

  /// 카드 한 장 이미지만 설명까지 넣는다
  final bool showsDescription;

  /// 카드 모서리 · 안쪽 여백 · 그림↔글 간격 (A4 포인트)
  static const _radius = 16.0;
  static const _inset = 10.0;
  static const _pictureToText = 8.0;
  static const _numberSize = 30.0;
  static const _pictogramInset = 4.0;

  /// 흑백 테마: 받은 그림(AI·사진)만 회색으로 (번들 픽토그램은 라이선스상 변형하지 않음)
  static const _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final style = _PrintCardStyle.of(options.theme, index, context.colors);
    // 그림이 없으면 그림 칸에 제목을 크게 넣으므로 아래 글 줄은 두지 않음 (같은 제목이 두 번 찍히지 않게)
    final hasText = options.shouldIncludeText && picture.hasPicture;
    return Container(
      decoration: BoxDecoration(
        color: style.fill,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: style.border, width: style.borderWidth),
      ),
      padding: const EdgeInsets.all(_inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: options.theme == CardDesignTheme.largeText ? 3 : 5,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_radius - _inset / 2),
                    child: _picture(context, style),
                  ),
                ),
                if (showsNumber)
                  Positioned(left: 0, top: 0, child: _number(context, style)),
              ],
            ),
          ),
          if (hasText) ...[
            const SizedBox(height: _pictureToText),
            Expanded(
              flex: options.theme == CardDesignTheme.largeText ? 3 : 2,
              child: _texts(context),
            ),
          ],
        ],
      ),
    );
  }

  // 그림 자리: 받은 그림 > 예시 > 픽토그램 > 제목만 크게 (빈 칸으로 찍히지 않게)
  Widget _picture(BuildContext context, _PrintCardStyle style) {
    final bytes = picture.bytes;
    if (bytes != null) {
      final image = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
      return style.isGrayscalePicture
          ? ColorFiltered(colorFilter: _grayscale, child: image)
          : image;
    }
    Widget titleOnly(BuildContext context) => ColoredBox(
      color: context.colors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(_inset),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _title(context, maxLines: 3),
          ),
        ),
      ),
    );
    if (picture.exampleImageId case final id?) {
      return ExampleCardArt(id: id, label: card.displayTitle, fallbackBuilder: titleOnly);
    }
    if (picture.pictogramId case final id?) {
      // 앱용 PictogramArt 는 여백이 화면 기준이라 작은 칸에서 그림이 줄어듦 > 인쇄는 여백을 칸 비율로
      return ColoredBox(
        color: context.colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(_pictogramInset),
          child: SvgPicture(
            PictogramSvgLoader(id),
            fit: BoxFit.contain,
            errorBuilder: (context, _, _) => titleOnly(context),
          ),
        ),
      );
    }
    return titleOnly(context);
  }

  Widget _number(BuildContext context, _PrintCardStyle style) => Container(
    width: _numberSize,
    height: _numberSize,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: style.numberFill, shape: BoxShape.circle),
    child: Text(
      '${index + 1}',
      style: context.typo.printCardNumber.copyWith(color: style.numberText),
    ),
  );

  Widget _texts(BuildContext context) => ContentLocale(
    language: language,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 긴 문장은 잘리지 않게 글자를 줄여 맞춘다 (최대 2줄)
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _title(context, maxLines: 2),
          ),
        ),
        if (showsDescription && card.description != card.displayTitle) ...[
          const SizedBox(height: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                card.description,
                textAlign: TextAlign.center,
                maxLines: 3,
                style: context.typo.printCardDescription.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _title(BuildContext context, {required int maxLines}) => Text(
    card.displayTitle,
    textAlign: TextAlign.center,
    maxLines: maxLines,
    style: (options.theme == CardDesignTheme.largeText
            ? context.typo.printCardTitleLarge
            : context.typo.printCardTitle)
        .copyWith(color: context.colors.textPrimary),
  );
}

/// 테마 > 카드 색·선 (테마 하나 더하기 = 여기 한 줄 + [CardDesignTheme] 값 하나)
class _PrintCardStyle {
  const _PrintCardStyle({
    required this.fill,
    required this.border,
    required this.borderWidth,
    required this.numberFill,
    required this.numberText,
    this.isGrayscalePicture = false,
  });

  final Color fill;
  final Color border;
  final double borderWidth;
  final Color numberFill;
  final Color numberText;
  final bool isGrayscalePicture;

  static _PrintCardStyle of(CardDesignTheme theme, int index, AppColors colors) {
    final palette = CardPalette.at(index);
    return switch (theme) {
      // 앱 카드 그대로
      CardDesignTheme.basic => _PrintCardStyle(
        fill: palette.fill,
        border: palette.border,
        borderWidth: 2,
        numberFill: palette.border,
        numberText: colors.surface,
      ),
      // 장식 없이 흰 바탕 + 굵은 검은 테두리
      CardDesignTheme.simple => _PrintCardStyle(
        fill: colors.surface,
        border: colors.textPrimary,
        borderWidth: 4,
        numberFill: colors.textPrimary,
        numberText: colors.surface,
      ),
      // 흰 바탕 + 얇은 회색 선 (잉크 절약)
      CardDesignTheme.inkSaver => _PrintCardStyle(
        fill: colors.surface,
        border: colors.textPlaceholder,
        borderWidth: 1,
        numberFill: colors.textPlaceholder,
        numberText: colors.textPrimary,
      ),
      // 흰 바탕 + 검은 선 + 그림 흑백
      CardDesignTheme.monochrome => _PrintCardStyle(
        fill: colors.surface,
        border: colors.textPrimary,
        borderWidth: 2,
        numberFill: colors.textPrimary,
        numberText: colors.surface,
        isGrayscalePicture: true,
      ),
      // 앱 카드 색 + 굵은 테두리 (글자를 크게 쓰는 쪽은 PrintCard 가 정함)
      CardDesignTheme.largeText => _PrintCardStyle(
        fill: palette.fill,
        border: palette.border,
        borderWidth: 4,
        numberFill: palette.border,
        numberText: colors.surface,
      ),
    };
  }
}
