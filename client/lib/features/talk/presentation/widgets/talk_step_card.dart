import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../guardian/domain/card_palette.dart';
import '../../domain/talk_post.dart';
import 'talk_step_image.dart';

/// 이야기 상세 카드 한 장 (시안 1813:7501): 순서별 색 판 > 그림 313×230 > 번호 · 제목 > 설명
/// 일과 카드와 같은 모양. 시안 단위(333×410)로 그리고 [width] 에 맞춰 통째로 줄인다
/// (한 눈에 보기 격자 1813:7733 은 같은 카드의 0.53배)
class TalkStepCard extends StatelessWidget {
  const TalkStepCard({
    super.key,
    required this.postId,
    required this.step,
    required this.index,
    required this.width,
  });

  final String postId;
  final TalkStep step;

  /// 색을 정하는 목록 순서 (0부터, 5색을 돌려 쓴다)
  final int index;

  /// 화면에 그릴 폭. 높이는 시안 비율을 따른다
  final double width;

  /// 시안 카드 크기
  static const designWidth = 333.0;
  static const designHeight = 410.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * designHeight / designWidth,
      child: FittedBox(
        child: SizedBox(
          width: designWidth,
          height: designHeight,
          child: _DesignCanvas(postId: postId, step: step, index: index),
        ),
      ),
    );
  }
}

/// 시안 단위 카드 본체. 바깥 [FittedBox] 가 비율을 맞추므로 여기서는 `.w` 를 쓰지 않는다
class _DesignCanvas extends StatelessWidget {
  const _DesignCanvas({
    required this.postId,
    required this.step,
    required this.index,
  });

  final String postId;
  final TalkStep step;
  final int index;

  /// 테두리 포함 안쪽 여백 · 테두리 · 판 반지름 · 그림 반지름 (시안 10 · 2 · 20 · 10)
  static const _inset = 10.0;
  static const _borderWidth = 2.0;
  static const _cardRadius = 20.0;
  static const _imageRadius = 10.0;

  /// 그림칸 비율 (313×230)
  static const _imageAspect = 313 / 230;

  /// 그림 > 번호 줄 > 설명 간격 (시안 10 · 18)
  static const _imageToTitle = 10.0;
  static const _titleToBody = 18.0;

  /// 번호 배지 한 변 · 반지름 · 배지 > 제목 (시안 40 · 12 · 8)
  static const _badgeSize = 40.0;
  static const _badgeRadius = 12.0;
  static const _badgeToTitle = 8.0;

  /// 그림자 (0 2 5 · 5%)
  static const _shadowBlur = 5.0;
  static const _shadowOffsetY = 2.0;

  /// 제목 · 설명 최대 줄 수 (설명 자리 92 = 20 × 1.2 × 3줄)
  static const _titleMaxLines = 2;
  static const _descriptionMaxLines = 3;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final palette = CardPalette.at(index);
    final title = step.title ?? '';

    return Container(
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: palette.border, width: _borderWidth),
        boxShadow: [
          BoxShadow(
            color: colors.glassShadow,
            blurRadius: _shadowBlur,
            offset: const Offset(0, _shadowOffsetY),
          ),
        ],
      ),
      // 시안 여백은 테두리를 포함한 값 (Container 가 테두리만큼 이미 띄운다)
      padding: const EdgeInsets.all(_inset - _borderWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: _imageAspect,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_imageRadius),
              child: TalkStepImage(postId: postId, step: step),
            ),
          ),
          const SizedBox(height: _imageToTitle),
          // 번호 · 제목 (두 줄이면 배지와 가운데 맞춤)
          Row(
            children: [
              Container(
                width: _badgeSize,
                height: _badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(_badgeRadius),
                ),
                child: Text(
                  '${step.cardNumber}',
                  textAlign: TextAlign.center,
                  style: typo.cardHeadline.copyWith(color: colors.surface),
                ),
              ),
              const SizedBox(width: _badgeToTitle),
              Expanded(
                child: Text(
                  title,
                  maxLines: _titleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: typo.actionCardTitle.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: _titleToBody),
          // 설명은 배지 끝(제목 시작)에 맞춘다. 카드 높이는 고정이라 넘치면 줄임표
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: _badgeSize + _badgeToTitle),
              child: Text(
                step.description,
                overflow: TextOverflow.ellipsis,
                maxLines: _descriptionMaxLines,
                style: typo.cardDescription.copyWith(color: colors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
