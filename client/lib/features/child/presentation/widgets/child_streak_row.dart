import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pop_in.dart';
import '../../../member/application/elumi_streak_providers.dart';

/// 이룸이 홈 연속 기록 판: 큰 불꽃 + `N일 이어서 했어요` + 별 줄 (하루에 별 하나, 최대 7개)
/// 2일 미만이면 자리 없음. 재촉하는 말 없이 해낸 것만 보여 줌
class ChildStreakRow extends ConsumerWidget {
  const ChildStreakRow({super.key, this.topGap = 0});

  /// 판 위 간격 (보일 때만)
  final double topGap;

  /// 별 줄 최대 개수 (한 주)
  static const _maximumStarCount = 7;

  /// 불꽃 그림 · 별 크기 · 별 사이 · 판 안쪽 여백 · 그림 > 글 · 글 > 별 줄 · 판 모서리
  static const _flameSize = 56.0;
  static const _starSize = 28.0;
  static const _starGap = 4.0;
  static const _padding = 16.0;
  static const _flameToText = 12.0;
  static const _textToStars = 8.0;
  static const _radius = 20.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(elumiStreakProvider);
    if (!streak.isVisible) return const SizedBox.shrink();
    final colors = context.colors;
    final starCount = streak.days.clamp(0, _maximumStarCount);
    final panel = Container(
      padding: EdgeInsets.all(_padding.w),
      decoration: BoxDecoration(color: colors.infoHighlightPeachFill, borderRadius: BorderRadius.circular(_radius.r)),
      child: Row(
        children: [
          // 일수가 바뀌면 다시 톡 튐 (500ms, 이룸이 화면 300ms 이상)
          AppPopIn(
            key: ValueKey(streak.days),
            child: Image.asset(
              AppAssets.featureIconStreak,
              width: _flameSize.w,
              height: _flameSize.w,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
          SizedBox(width: _flameToText.w),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.childStreakDays(streak.days),
                  style: context.typo.childGreeting.copyWith(color: colors.textPrimary),
                ),
                SizedBox(height: _textToStars.h),
                Wrap(
                  spacing: _starGap.w,
                  runSpacing: _starGap.w,
                  children: [
                    for (var index = 0; index < starCount; index++)
                      Image.asset(
                        AppAssets.featureIconStar,
                        width: _starSize.w,
                        height: _starSize.w,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Padding(padding: EdgeInsets.only(top: topGap.h), child: panel);
  }
}
