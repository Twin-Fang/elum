import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/child_haptics.dart';
import '../../../core/assets/app_assets.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/routine_progress_ring.dart';
import '../../../core/l10n/content_locale.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../shared/models/routine.dart';
import '../../../core/router/routes.dart';

/// 일과 한 줄 (Figma 356:5079).
///
/// 미완료는 회색 + 진행률 링, 전부 끝내면 민트 배경 + 채운 체크.
/// 탭하면 카드 상세로 들어간다.
class ChildRoutineTile extends StatelessWidget {
  const ChildRoutineTile({
    super.key,
    required this.routine,
    required this.progress,
  });

  final Routine routine;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final isDone = progress >= 1.0;

    return AppPressable(
      onTap: () {
        playChildHaptic(context, ChildHapticKind.tap);
        context.push(Routes.childRoutineDetail, extra: routine);
      },
      scaleDown: AppPressable.scaleCard,
      child: Container(
        // 보상이 있으면 한 줄이 늘어 타일이 높아진다. 시안은 92.
        // 최소 높이만 정한다 — 큰 글자 설정에서 내용이 더 높아지면 넘치지 않고 늘어난다.
        constraints: BoxConstraints(minHeight: (routine.hasReward ? 92 : 68).h),
        // Figma 실측 — 제목 좌 24, 화살표 우 16
        padding: EdgeInsets.only(left: 24.w, right: 16.w),
        decoration: BoxDecoration(
          color: isDone ? colors.childTileDone : colors.routineTileBg,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentLocale(
                    language: routine.language,
                    child: Text(
                      routine.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // 시안 제목은 18/800이다.
                      style: context.typo.childDetailTitle.copyWith(
                        color: colors.chipLabel,
                      ),
                    ),
                  ),
                  // 목록에서부터 "다 하면 뭘 받는지"가 보인다.
                  // 들어가야 알 수 있으면 시작할 이유가 약해진다.
                  // 시안: `다하면`은 회색(#74757D), 보상은 검정 70% — 둘 다 16.
                  if (routine.hasReward) ...[
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Text(
                          context.l10n.childHomeRewardPrefix,
                          style: context.typo.body.copyWith(
                            color: colors.routineTileLabel,
                          ),
                        ),
                        SizedBox(width: space.xs),
                        Expanded(
                          child: ContentLocale(
                            language: routine.language,
                            child: Text(
                              routine.rewardDisplay,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.typo.body.copyWith(
                                color: Colors.black.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: space.xs),
            RoutineProgressRing(progress: progress, boldCheck: true),
            SizedBox(width: space.xs),
            // 아래 방향 원본을 반시계 90° 돌려 `>`로 만든다
            Transform.rotate(
              angle: -math.pi / 2,
              child: SvgPicture.asset(
                AppAssets.iconAngleSmall,
                width: 24.w,
                height: 24.w,
                // 시안 PNG 실측 #74757D (`다하면` 글자와 같은 회색)
                colorFilter: ColorFilter.mode(
                  colors.routineTileLabel,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
