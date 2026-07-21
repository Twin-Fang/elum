import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/action_card.dart';
import '../../domain/card_palette.dart';
import 'card_image.dart';

/// 행동 카드 한 장.
///
/// Figma `카드확인`(262:5124)과 `아이_홈`(309:3548)이 같은 카드를 쓴다.
/// 345×431 / r20 / 2px 테두리, 안에 이미지·번호·제목·설명이 들어간다.
///
/// 보호자용에는 `수정` 버튼이, 아이용에는 없다. [onEdit]으로 가른다.
class ActionCardView extends StatelessWidget {
  const ActionCardView({
    super.key,
    required this.card,
    required this.index,
    this.routineId = '',
    this.onEdit,
    this.onSpeak,
    this.isSpeaking = false,
  });

  final ActionCard card;

  /// 이미지를 받아오는 데 쓴다. 비면 대체 일러스트를 그린다.
  final String routineId;

  /// 색을 정하는 순서. `stepOrder`가 아니라 목록 인덱스다 —
  /// 서버가 순서를 1부터 주지 않을 수도 있다.
  final int index;

  /// null이면 수정 버튼을 그리지 않는다 (아이 모드)
  final VoidCallback? onEdit;

  /// 소리로 읽어주기.
  final VoidCallback? onSpeak;

  /// 지금 이 카드를 읽고 있는가. 아이콘 상태가 바뀐다.
  final bool isSpeaking;

  /// Figma 실측 — 카드 안 스피커 아이콘 24×24
  static const _volumeIconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final palette = CardPalette.at(index);
    final space = context.space;

    return Container(
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(space.cardRadius),
        border: Border.all(color: palette.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: context.colors.glassShadow,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Illustration(
              routineId: routineId,
              stepId: card.id,
              onEdit: onEdit,
            ),
          ),
          SizedBox(height: space.md),
          Row(
            children: [
              _NumberBadge(order: index + 1, color: palette.border),
              SizedBox(width: space.sm),
              Expanded(
                child: Text(
                  card.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.cardHeadline
                      .copyWith(color: context.colors.textPrimary),
                ),
              ),
            ],
          ),
          SizedBox(height: space.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPressable(
                onTap: onSpeak,
                scaleDown: AppPressable.scaleIcon,
                // SVG가 25×25인데 Figma 배치는 24×24다. 크기만 지정하면
                // 비율이 눌려 아이콘이 찌그러진다 — contain으로 비율을 지킨다.
                child: SizedBox(
                  width: _volumeIconSize,
                  height: _volumeIconSize,
                  // 읽는 중에는 흐리게 — 다시 누르면 멈춘다는 신호다
                  child: AnimatedOpacity(
                    duration: AppMotion.fast,
                    opacity: isSpeaking ? 0.45 : 1,
                    child: SvgPicture.asset(
                      AppAssets.iconVolume,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              SizedBox(width: space.sm),
              Expanded(
                child: Text(
                  card.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.typo.cardDescription
                      .copyWith(color: context.colors.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 카드 이미지 자리.
///
/// 서버가 만든 그림을 보여주고, 못 받으면 캐릭터 일러스트로 대체한다.
/// 자리를 비우면 카드 비율이 무너진다.
class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.routineId,
    required this.stepId,
    this.onEdit,
  });

  final String routineId;
  final String stepId;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(space.xs),
            ),
            child: Padding(
              padding: EdgeInsets.all(space.md),
              child: CardImage(routineId: routineId, stepId: stepId),
            ),
          ),
        ),
        if (onEdit != null)
          Positioned(
            top: space.sm,
            right: space.sm,
            child: _EditButton(onTap: onEdit!),
          ),
      ],
    );
  }
}

/// Figma `수정` 버튼 (padding 10×16, r20)
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(context.space.cardRadius),
        ),
        child: Text(
          '수정',
          style: context.typo.chipLabel
              .copyWith(color: context.colors.chipLabel),
        ),
      ),
    );
  }
}

/// 순서 배지 (40×40, r12)
class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.order, required this.color});

  final int order;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$order',
        style: context.typo.cardHeadline
            .copyWith(color: context.colors.surface),
      ),
    );
  }
}
