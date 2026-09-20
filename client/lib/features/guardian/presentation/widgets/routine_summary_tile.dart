import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/routine_progress_ring.dart';
import '../../../../shared/models/routine.dart';

/// 일과 한 줄 (Figma 931:3896 — 361×68, r20, #EEE9E6).
///
/// 개편 전에는 이 자리가 접힌 타일이었고 탭하면 카드 목록이 펼쳐졌다. 지금은
/// **제목·보상·진행률만 요약해 보여주고**, 카드를 보거나 고치는 일은 수정
/// 화면으로 넘긴다. 목록에서 여러 개가 펼쳐지면 끝없이 길어지던 문제가
/// 사라지고, 한 줄의 높이가 항상 같아 순서를 바꿀 때 자리가 튀지 않는다.
///
/// 지난 일과는 날짜와 `일과 다시하기`가 붙어 105로 자란다 ([onRerun]).
class RoutineSummaryTile extends StatelessWidget {
  const RoutineSummaryTile({
    super.key,
    required this.routine,
    required this.progress,
    this.onTap,
    this.dragHandle,
    this.showDate = false,
    this.onRerun,
    this.highlighted = false,
  });

  final Routine routine;

  /// 0.0 ~ 1.0. 1이면 링 대신 채워진 체크가 선다.
  final double progress;

  final VoidCallback? onTap;

  /// 순서 바꾸기 손잡이. null이면 자리도 차지하지 않는다 —
  /// 지난 일과는 순서를 바꿀 수 없다.
  final Widget? dragHandle;

  /// 날짜를 보여줄지. 오늘 일과는 전부 오늘이라 적을 이유가 없다.
  final bool showDate;

  /// `일과 다시하기`. null이면 버튼도 없고 카드도 68로 선다.
  final VoidCallback? onRerun;

  /// 밀려 있거나 들려 있는 중인가. 배경이 한 단계 어두워진다.
  final bool highlighted;

  // --- Figma 실측 ---
  static const _shortHeight = 68.0;
  static const _tallHeight = 105.0;

  /// 빈 상태·로딩 타일도 같은 자리에서 글이 시작해야 한 목록으로 읽힌다.
  static const padLeft = 18.0;

  /// 손잡이가 있으면 오른쪽 여백이 18, 없으면 링이 그만큼 바깥으로 나간다.
  static const _padRightWithHandle = 18.0;
  static const _padRightPlain = 14.0;

  /// 링과 손잡이 사이
  static const _ringToHandle = 10.0;

  /// 제목 위 16 · 제목과 보상 줄 사이 8 · 보상 줄과 날짜 사이 21
  static const _padTop = 16.0;
  static const _titleToMeta = 8.0;
  static const _metaToDate = 21.0;

  /// 링 위 14 · 링과 다시하기 사이 7
  static const _ringTop = 14.0;
  static const _ringToRerun = 7.0;

  /// 손잡이 위 25 (18 높이가 68 한가운데 서도록)
  static const _handleTop = 25.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final hasRerun = onRerun != null;
    // 날짜 줄이나 다시하기 버튼이 붙으면 68로는 담기지 않는다. 둘 중 하나만
    // 켜도 키운다 — 높이를 켜는 쪽과 내용을 넣는 쪽이 어긋나면 화면이 잘린다.
    final isTall = hasRerun || (showDate && routine.scheduledDateLabel.isNotEmpty);

    final card = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      height: (isTall ? _tallHeight : _shortHeight).h,
      decoration: BoxDecoration(
        color: highlighted ? colors.routineTileSwiped : colors.routineTileBg,
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: padLeft.w),
          Expanded(child: _texts(context)),
          _trailing(context, hasRerun: hasRerun),
          if (dragHandle case final handle?) ...[
            SizedBox(width: _ringToHandle.w),
            Padding(
              padding: EdgeInsets.only(top: _handleTop.h),
              child: handle,
            ),
            SizedBox(width: _padRightWithHandle.w),
          ] else
            SizedBox(width: _padRightPlain.w),
        ],
      ),
    );

    if (onTap == null) return card;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: card,
    );
  }

  Widget _texts(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final dateLabel = routine.scheduledDateLabel;
    final showsDate = showDate && dateLabel.isNotEmpty;

    final title = Text(
      routine.displayTitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: typo.routineTileTitle.copyWith(color: colors.chipLabel),
    );

    // 보상도 날짜도 없으면 제목 하나뿐이다. 위에서 16 띄우면 아래로 처져 보인다.
    if (!routine.hasReward && !showsDate) {
      return Align(alignment: Alignment.centerLeft, child: title);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: _padTop.h),
        title,
        if (routine.hasReward) ...[
          SizedBox(height: _titleToMeta.h),
          _RewardLine(routine: routine),
        ],
        if (showsDate) ...[
          SizedBox(height: routine.hasReward ? _metaToDate.h : _titleToMeta.h),
          Text(
            dateLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.routineTileMeta.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _trailing(BuildContext context, {required bool hasRerun}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: _ringTop.h),
        RoutineProgressRing(progress: progress),
        if (hasRerun) ...[
          SizedBox(height: _ringToRerun.h),
          _RerunButton(onTap: onRerun!),
        ],
      ],
    );
  }
}

/// `완료 시 · 유튜브 시청 20분` 한 줄.
///
/// 라벨과 값이 같은 크기라 굵기로만 갈린다 — 크기까지 다르면 한 문장으로
/// 읽히지 않고 두 덩어리로 흩어진다.
class _RewardLine extends StatelessWidget {
  const _RewardLine({required this.routine});

  final Routine routine;

  /// Figma 실측 — `완료 시`(18~55)와 값(61~) 사이
  static const _labelGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return Row(
      children: [
        Text(
          '완료 시',
          style: typo.routineTileMeta.copyWith(color: colors.routineTileLabel),
        ),
        SizedBox(width: _labelGap.w),
        Flexible(
          child: Text(
            routine.rewardText.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typo.routineTileReward
                .copyWith(color: colors.routineTileReward),
          ),
        ),
      ],
    );
  }
}

/// 지난 일과를 그대로 다시 만든다 (Figma 931:4449 — r12, 패딩 10/20).
class _RerunButton extends StatelessWidget {
  const _RerunButton({required this.onTap});

  final VoidCallback onTap;

  static const _radius = 12.0;
  static const _padH = 20.0;
  static const _padV = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleButton,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
        decoration: BoxDecoration(
          // 카드보다 밝다 — 카드 위에 얹힌 것이라 같은 색이면 눌리는 자리로 안 보인다.
          color: colors.background,
          borderRadius: BorderRadius.circular(_radius.w),
        ),
        child: Text(
          '일과 다시하기',
          style: context.typo.chipLabel.copyWith(color: colors.routineTileLabel),
        ),
      ),
    );
  }
}

/// 순서 바꾸기 손잡이 (Figma 931:4390 — 18×18, 막대 셋).
///
/// 에셋으로 두지 않고 그린다. 막대 세 줄이라 좌표가 전부 시안에 있고,
/// 색을 상태에 따라 바꿔야 해서 파일로 두면 오히려 손이 더 간다.
class RoutineDragHandle extends StatelessWidget {
  const RoutineDragHandle({super.key});

  static const _size = 18.0;
  static const _barHeight = 2.25;
  static const _barGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.routineDragHandle;

    return SizedBox(
      // 정사각형 — 가로세로 모두 .w
      width: _size.w,
      height: _size.w,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(height: _barGap.h),
            Container(
              width: _size.w,
              height: _barHeight.h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(_barHeight.h),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `오늘 일과` · `지난 일과` 섹션 제목 (Figma 931:3909 — 아이콘 18 + 간격 8).
class RoutineSectionTitle extends StatelessWidget {
  const RoutineSectionTitle({
    super.key,
    required this.iconAsset,
    required this.label,
  });

  final String iconAsset;
  final String label;

  static const _iconSize = 18.0;
  static const _gap = 8.0;

  /// 카드는 화면 끝에서 16, 제목은 그보다 8 더 안쪽이다.
  static const _inset = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _inset.w),
      child: Row(
        children: [
          // 정사각형 아이콘 — 가로세로 모두 .w
          SvgPicture.asset(iconAsset, width: _iconSize.w, height: _iconSize.w),
          SizedBox(width: _gap.w),
          Text(
            label,
            style: context.typo.routineSectionLabel
                .copyWith(color: colors.routineTileLabel),
          ),
        ],
      ),
    );
  }
}
