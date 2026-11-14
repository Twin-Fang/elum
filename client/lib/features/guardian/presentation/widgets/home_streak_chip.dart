import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pop_in.dart';
import '../../../member/application/elumi_streak_providers.dart';
import '../../../member/application/member_providers.dart';
import '../../../member/domain/elumi_streak.dart';
import '../../../profile/application/profile_session.dart';
import '../../application/guardian_child_identity.dart';
import '../../application/home_coach_notifier.dart';
import '../../application/streak_milestone_celebration.dart';
import 'streak_milestone_dialog.dart';

/// 보호자 홈 연속 기록: 작은 불꽃 칩 (`N일 연속`, 톡 튐) + (오늘 안 마쳤으면) 이어 가기 한 줄
/// 2일 미만이면 자리 없음. 축하 일수(3 · 7 · 14 · 30)에 처음 닿으면 축하 창 한 번 (이룸이마다)
class HomeStreakChip extends ConsumerStatefulWidget {
  const HomeStreakChip({super.key, required this.bottomGap});

  /// 칩 아래 간격 (보일 때만)
  final double bottomGap;

  @override
  ConsumerState<HomeStreakChip> createState() => _HomeStreakChipState();
}

class _HomeStreakChipState extends ConsumerState<HomeStreakChip> {
  /// 불꽃 그림 · 칩 안쪽 여백 · 그림 > 글 간격 · 칩 > 한 줄 간격
  static const _iconSize = 24.0;
  static const _horizontalPadding = 12.0;
  static const _verticalPadding = 6.0;
  static const _iconToText = 6.0;
  static const _chipToLine = 6.0;

  // 축하 창을 띄우는 중 (프레임마다 겹쳐 띄우지 않게)
  bool _isCelebrating = false;

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(elumiStreakProvider);
    final isCoachActive = ref.watch(homeCoachProvider.select((state) => state.active));
    if (streak.reachedMilestone != null && !isCoachActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate(streak));
    }
    if (!streak.isVisible) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomGap.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 일수가 바뀌면 다시 톡 튐
          AppPopIn(key: ValueKey(streak.days), child: _chip(context, streak.days)),
          if (streak.isAtRiskToday) ...[
            SizedBox(height: _chipToLine.h),
            Text(
              context.l10n.streakAtRiskLine(streak.days + 1),
              style: context.typo.creditBody.copyWith(color: context.colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// 연한 피치 알약 + 불꽃 3D 그림 + 굵은 `N일 연속`
  Widget _chip(BuildContext context, int days) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w, vertical: _verticalPadding.h),
      decoration: BoxDecoration(
        color: colors.infoHighlightPeachFill,
        borderRadius: BorderRadius.circular(context.space.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            AppAssets.featureIconStreak,
            width: _iconSize.w,
            height: _iconSize.w,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          SizedBox(width: _iconToText.w),
          Text(
            context.l10n.streakChipDays(days),
            style: context.typo.creditBody.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// 축하 일수에 처음 닿았으면 축하 창: 홈이 맨 위일 때만 > 기록 먼저 (다시 안 뜨게) > 창
  Future<void> _maybeCelebrate(ElumiStreak streak) async {
    if (!mounted || _isCelebrating) return;
    final isHomeOnTop = ModalRoute.of(context)?.isCurrent ?? false;
    if (!isHomeOnTop || ref.read(homeCoachProvider).active) return;
    final profileId =
        ref.read(profileSessionProvider).selectedId ?? ref.read(memberProvider).value?.profiles.firstOrNull?.id;
    final celebration = ref.read(streakMilestoneCelebrationProvider);
    final milestone = celebration.milestoneToCelebrate(profileId: profileId, streak: streak);
    if (profileId == null || milestone == null) return;
    _isCelebrating = true;
    try {
      await celebration.markCelebrated(profileId: profileId, milestone: milestone);
      if (!mounted) return;
      await showStreakMilestoneDialog(
        context,
        milestoneDays: milestone,
        elumiName: ref.read(guardianChildIdentityProvider).name,
      );
    } catch (e, stack) {
      // 축하 창 실패는 홈을 막지 않음 (기록은 남아 다시 뜨지 않음)
      AppLogger.error('streakMilestone', e, stack, {'step': 'show'});
    } finally {
      _isCelebrating = false;
    }
  }
}
