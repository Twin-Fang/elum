import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/routine.dart';

/// 이룸이 화면의 보상 칩 (이슈 #239 · 시안 #445).
///
/// **같은 보상을 두 곳에서 보여준다** — 수행 중(일과 진행)과 완료(보상 화면).
/// 두 곳이 따로 그리면 문구와 모양이 어긋나므로 한 위젯으로 묶었다.
///
/// ## 🔴 수행 중에도 계속 보인다
///
/// 2026-09-13 서울 ABA연구소 자문의 핵심 요구다. **완료 후에만 보여주는 별(⭐)
/// 연출과 다른 기능이다** — 하는 동안 "다 하면 무엇을 받는지"가 보여야 끝까지 간다.
///
/// ## 보상이 없으면 아무것도 그리지 않는다
///
/// 보호자가 건너뛸 수 있다. 빈 자리를 남기면 무엇이 빠진 것처럼 보이므로
/// [maybe]가 `SizedBox.shrink()`를 준다.
///
/// 시안(`1197:6775` · `1197:6942`)은 두 곳 모두 333폭·패딩 16/20·모서리 8의 칩에
/// `다하면 젤리 4개 먹기` 한 줄을 Pretendard 600/16 으로 쓴다. 밝은 화면은 #EEE9E6,
/// 어두운 보상 화면은 같은 색 30%다.
class RewardBanner extends StatelessWidget {
  const RewardBanner({
    super.key,
    required this.emoji,
    required this.text,
    this.onDark = false,
  });

  /// 보상이 있을 때만 그린다. 없으면 자리도 없다.
  static Widget maybe(Routine routine, {bool onDark = false}) {
    if (!routine.hasReward) return const SizedBox.shrink();
    return RewardBanner(
      emoji: routine.rewardEmoji,
      text: routine.rewardText,
      onDark: onDark,
    );
  }

  final String emoji;
  final String text;

  /// 어두운 배경(보상 화면) 위인가. 칩 바탕이 반투명으로 바뀐다.
  final bool onDark;

  /// 칩 폭 (시안 333). 화면 폭에서 좌우 30을 뺀 값과 같다.
  static const width = 333.0;

  /// 칩 높이 — 패딩 16 + 글자 16 + 패딩 16. 보상이 없을 때 자리를 비워 둘 때 쓴다.
  static const height = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 직접 적은 보상에는 그림이 없다. 빈 글자를 그대로 두면 문구 앞에 빈칸만 남는다 (#275).
    final display = emoji.isEmpty ? text : '$emoji $text';

    return Container(
      width: width.w,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
      decoration: BoxDecoration(
        color: onDark
            ? colors.routineTileBg.withValues(alpha: 0.3)
            : colors.routineTileBg,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text.rich(
        // 시안 PNG 실측: `다하면`과 보상 글자의 색이 다르다. 밝은 화면은 회색(#74757D)
        // 과 짙은 민트(#40BBA6), 어두운 화면은 흰색과 민트(#55CFBA)다.
        // Figma 덤프는 글자 구간별 색을 주지 않아 한 색으로 보인다 (#445).
        TextSpan(
          children: [
            TextSpan(
              text: '다하면 ',
              style: TextStyle(
                color: onDark ? colors.surface : colors.routineTileLabel,
              ),
            ),
            TextSpan(
              text: display,
              style: TextStyle(
                color: onDark ? colors.checkDone : colors.rewardChipHighlight,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: context.typo.rewardChipLabel,
      ),
    );
  }
}
