import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'coach_mark_parts.dart';

/// 코치마크 진행 알약: 점 + 안내 문구 한 줄 (마지막 단계는 닫기 안내)
///
/// 진한 판 위에 얹어 뒤 화면 글자와 겹쳐 읽히지 않게 한다 (#1294). 평소 화면 맨 아래, 대상이 아래쪽이면 ✕ 와 같은 줄
class CoachMarkFooter extends StatelessWidget {
  const CoachMarkFooter({
    super.key,
    required this.stepCount,
    required this.index,
    required this.isLast,
    required this.isMotionReduced,
    this.isAtTop = false,
  });

  final int stepCount;
  final int index;
  final bool isLast;

  /// 동작 줄이기를 켠 사람은 문구 전환 연출 없이 바로 바꿈
  final bool isMotionReduced;

  /// 위쪽(✕ 와 같은 줄)에 둔다 — 가리키는 대상이 화면 아래쪽이라 말풍선이 아래 자리를 쓸 때 (#834)
  final bool isAtTop;

  /// 화면 맨 아래에서 띄우는 거리 (안전영역 제외)
  static const bottomGap = 16.0;

  /// 알약 높이 (점·문구 한 줄 + 위아래 여백). 말풍선·시범이 이 자리를 피한다
  static const height = 44.0;

  /// 위쪽에 둘 때 안전영역 아래로 띄우는 거리 (✕ 버튼 줄 = 8)
  static const _topGap = 8.0;

  /// 위쪽에 둘 때 좌우로 비울 폭 (✕ 버튼 48 + 여백)
  static const _topSideClearance = 64.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = context.colors;
    final space = context.space;
    final sideInset = isAtTop ? _topSideClearance.w : space.md.w;

    return Positioned(
      left: sideInset,
      right: sideInset,
      top: isAtTop ? media.padding.top + _topGap.h : null,
      bottom: isAtTop ? null : media.padding.bottom + bottomGap.h,
      child: ExcludeSemantics(
        child: Center(
          child: Container(
            constraints: BoxConstraints(minHeight: height.h),
            padding: EdgeInsets.symmetric(
              horizontal: space.md.w,
              vertical: space.xs.h,
            ),
            decoration: BoxDecoration(
              color: colors.coachBubble,
              borderRadius: BorderRadius.circular(space.pillRadius.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CoachDots(count: stepCount, index: index),
                SizedBox(width: space.sm.w),
                // 문구가 바뀔 때 툭 바뀌지 않고 겹쳐 사라지고 나타난다
                Flexible(
                  child: AnimatedSwitcher(
                    duration: isMotionReduced ? Duration.zero : AppMotion.fast,
                    child: Text(
                      isLast
                          ? context.l10n.coachTapToClose
                          : context.l10n.coachTapToNext,
                      key: ValueKey(isLast),
                      style: context.typo.body.copyWith(
                        color: colors.coachText.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
