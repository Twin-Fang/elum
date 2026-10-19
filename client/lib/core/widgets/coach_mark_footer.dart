import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../l10n/l10n_context.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'coach_mark_parts.dart';

/// 코치마크 아래쪽: 진행 점과 안내 문구 (마지막 단계는 닫기 안내)
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

  /// 위쪽에 둔다 — 가리키는 대상이 화면 아래쪽이라 말풍선이 아래 문구 자리를 쓸 때 (#834)
  final bool isAtTop;

  /// 점과 문구를 화면 바닥에서 띄우는 거리(안전영역 제외). 하단 배너 광고(약 60~100) 위에 놓는다 -
  /// 광고와 겹치면 글자가 광고 위에 얹혀 지저분하다.
  static const _bottomOffset = 112.0;

  /// 위쪽에 둘 때 안전영역 아래로 띄우는 거리 (닫기 버튼 높이 아래)
  static const _topOffset = 64.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final colors = context.colors;
    final typo = context.typo;

    return Positioned(
      left: 0,
      right: 0,
      top: isAtTop ? media.padding.top + _topOffset.h : null,
      bottom: isAtTop ? null : media.padding.bottom + _bottomOffset.h,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoachDots(count: stepCount, index: index),
            SizedBox(height: 12.h),
            // 문구가 바뀔 때 툭 바뀌지 않고 겹쳐 사라지고 나타난다.
            AnimatedSwitcher(
              duration: isMotionReduced ? Duration.zero : AppMotion.fast,
              child: Text(
                isLast
                    ? context.l10n.coachTapToClose
                    : context.l10n.coachTapToNext,
                key: ValueKey(isLast),
                style: typo.body.copyWith(
                  color: colors.coachText.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
