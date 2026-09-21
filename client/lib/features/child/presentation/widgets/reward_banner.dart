import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../shared/models/routine.dart';

/// 이룸이 화면의 보상 표시 (이슈 #239).
///
/// **같은 보상을 세 곳에서 보여준다** — 시작(크게) · 수행 중(작게) · 완료(크게).
/// 세 곳이 따로 그리면 문구와 그림이 어긋나므로 한 위젯으로 묶었다.
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
class RewardBanner extends StatelessWidget {
  const RewardBanner({
    super.key,
    required this.emoji,
    required this.text,
    this.compact = false,
  });

  /// 보상이 있을 때만 그린다. 없으면 자리도 없다.
  static Widget maybe(Routine routine, {bool compact = false}) {
    if (!routine.hasReward) return const SizedBox.shrink();
    return RewardBanner(
      emoji: routine.rewardEmoji,
      text: routine.rewardText,
      compact: compact,
    );
  }

  final String emoji;
  final String text;

  /// 수행 중 상단 바. 카드를 가리지 않게 낮고 글자도 작다.
  final bool compact;

  /// 이모지는 OS 폰트로 그려진다 — 타이포 토큰을 태우지 않는다.
  static const _emojiLarge = 28.0;
  static const _emojiSmall = 18.0;

  static const _padVLarge = 14.0;
  static const _padVSmall = 8.0;
  static const _padH = 16.0;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: (compact ? _padVSmall : _padVLarge).h,
        horizontal: _padH.w,
      ),
      decoration: BoxDecoration(
        color: colors.rewardBannerBg,
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // `다 하면` — 조건을 먼저 말해야 보상만 보고 넘어가지 않는다.
          Text(
            '다 하면',
            style: (compact ? context.typo.caption : context.typo.body)
                .copyWith(color: colors.textSecondary),
          ),
          SizedBox(width: _gap.w),
          // 직접 적은 보상에는 그림이 없다. 빈 글자를 그대로 두면 옆 여백만 남아
          // 문구가 가운데에서 밀려 보인다 (#275).
          if (emoji.isNotEmpty) ...[
            Text(
              emoji,
              style: TextStyle(
                fontSize: (compact ? _emojiSmall : _emojiLarge).sp,
              ),
            ),
            SizedBox(width: (_gap / 2).w),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (compact
                      ? context.typo.cardBody
                      : context.typo.childTileTitle)
                  .copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
