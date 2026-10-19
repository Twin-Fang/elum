import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/action_card.dart';
import '../../domain/card_palette.dart';
import 'action_card_illustration.dart';
import 'action_card_number_badge.dart';
import 'action_card_speaker_glyph.dart';
import 'card_image.dart';
import 'default_card_art.dart';

/// 태블릿 큰 행동 카드: 그림 + 번호·제목 + 소리·설명 + 카드 안 [action] 자리 (#789)
///
/// 카드가 가로로 넓으면 왼쪽 그림·오른쪽 글, 세로로 길면 위 그림·아래 글로 스스로 바꾼다.
/// 이룸이 상세는 [action] 에 체크 버튼을 넣어 무엇을 체크하는지 카드와 묶는다 (폰 시안 `1197:6775` 는 카드 아래 — 폰은 [ActionCardView] 그대로).
class ActionCardTabletView extends ConsumerWidget {
  const ActionCardTabletView({
    super.key,
    required this.card,
    required this.index,
    required this.routineId,
    required this.language,
    required this.isSpeaking,
    required this.onSpeak,
    required this.action,
  });

  final ActionCard card;

  /// 목록 순서 (번호 배지·카드 색)
  final int index;
  final String routineId;

  /// 카드 글의 언어 (일과 언어)
  final String language;
  final bool isSpeaking;
  final VoidCallback onSpeak;

  /// 카드 오른쪽 아래 자리 (이룸이 상세의 체크 버튼). null 이면 비운다
  final Widget? action;

  /// 가로형으로 그릴 카드 폭:높이 경계
  static const _landscapeAspectMin = 1.15;

  /// 폰 카드 대비 글자 배율 (카드가 폰보다 훨씬 크다)
  static const _textScale = 1.6;

  /// 테두리 두께·안쪽 여백·영역 간격 (393 기준)
  static const _borderWidth = 2.0;
  static const _inset = 16.0;
  static const _gap = 20.0;

  /// 카드 안 [action] 이 글 영역에서 차지할 수 있는 최대 높이 비율
  static const _actionMaxHeightRatio = 0.5;

  /// 스피커 아이콘 크기 (폰 24 의 태블릿 배율)
  static const _speakerSize = 40.0;

  /// 번호 배지 칸 크기 (폰 배지 40 을 키워 담는다)
  static const _badgeBoxSize = 56.0;

  /// [action] 뒤 흰 원의 여백 (민트 카드 위에서 회색 체크가 묻히지 않게, 393 기준)
  static const _actionBackdropPadding = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = CardPalette.at(index);
    final space = context.space;
    final imageState = watchCardImageState(
      ref,
      routineId: routineId,
      stepId: card.id,
      imagePath: card.imagePath,
    );
    // 그림이 없으면 제목이 그림 자리에 크게 들어간다 — 줄에 또 쓰지 않는다
    final isTitleInArt =
        imageState == CardImageState.none &&
        !showsPictogram(imageState, card.pictogramId);

    final illustration = ActionCardIllustration(
      routineId: routineId,
      stepId: card.id,
      imagePath: card.imagePath,
      pictogramId: card.pictogramId,
      pictogramLabel: card.displayTitle,
      emptyBuilder: (context) =>
          DefaultCardTitleArt(title: card.displayTitle, color: palette.border),
    );

    return ContentLocale(
      language: language,
      child: Container(
        decoration: BoxDecoration(
          color: palette.fill,
          borderRadius: BorderRadius.circular(space.cardRadius),
          border: Border.all(color: palette.border, width: _borderWidth.w),
          boxShadow: [
            BoxShadow(
              color: context.colors.glassShadow,
              blurRadius: 5.w,
              offset: Offset(0, 2.h),
            ),
          ],
        ),
        padding: EdgeInsets.all(_inset.w),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscapeCard =
                constraints.maxWidth >
                constraints.maxHeight * _landscapeAspectMin;
            final details = _buildDetails(context, palette, isTitleInArt);
            if (isLandscapeCard) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 11, child: illustration),
                  SizedBox(width: _gap.w),
                  Expanded(flex: 9, child: details),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 6, child: illustration),
                SizedBox(height: _gap.h),
                Expanded(flex: 4, child: details),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 글 영역: 번호·제목 > 소리·설명 (넘치면 스크롤) > 체크 버튼 (오른쪽 아래)
  Widget _buildDetails(
    BuildContext context,
    CardPalette palette,
    bool isTitleInArt,
  ) {
    final space = context.space;
    final typo = context.typo;
    final textColor = context.colors.textPrimary;
    final titleStyle = typo.actionCardTitle.copyWith(color: textColor);
    final descriptionStyle = typo.cardDescription.copyWith(color: textColor);
    // 글자 토큰은 그대로 두고 배율만 키운다 (사용자 글자 크기 설정 위에 곱한다)
    final textScaler = TextScaler.linear(
      MediaQuery.textScalerOf(context).scale(1) * _textScale,
    );

    final speaker = AppPressable(
      onTap: onSpeak,
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: isSpeaking
          ? context.l10n.cardSpeakStop
          : context.l10n.cardSpeak,
      child: ActionCardSpeakerGlyph(size: _speakerSize.w, speaking: isSpeaking),
    );

    // 낮은 창에서도 넘치지 않게 [action] 은 글 영역 높이의 절반까지만 쓰고 줄인다
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: _badgeBoxSize.w,
                        child: FittedBox(
                          child: ActionCardNumberBadge(
                            order: index + 1,
                            color: palette.border,
                          ),
                        ),
                      ),
                      SizedBox(width: space.sm),
                      if (!isTitleInArt)
                        Expanded(
                          // 무엇을 하라는 문장이라 자르지 않는다
                          child: Text(
                            card.displayTitle,
                            style: titleStyle,
                            textScaler: textScaler,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: space.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 스피커를 배지 칸 가운데에 둬 설명이 제목과 같은 x 에서 시작한다
                      SizedBox(
                        width: _badgeBoxSize.w,
                        child: Center(child: speaker),
                      ),
                      SizedBox(width: space.sm),
                      Expanded(
                        child: Text(
                          card.description,
                          style: descriptionStyle,
                          textScaler: textScaler,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (action != null)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * _actionMaxHeightRatio,
              ),
              child: Align(
                alignment: Alignment.bottomRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _ActionBackdrop(child: action!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 카드 안 버튼 뒤 흰 원 (카드 색 위에서 버튼 테두리가 또렷하게)
class _ActionBackdrop extends StatelessWidget {
  const _ActionBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.colors.surface,
      ),
      child: Padding(
        padding: EdgeInsets.all(ActionCardTabletView._actionBackdropPadding.w),
        child: child,
      ),
    );
  }
}
