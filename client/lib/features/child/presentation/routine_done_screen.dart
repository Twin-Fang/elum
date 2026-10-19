import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/child_haptics.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import 'widgets/child_night_sky_backdrop.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/router/routes.dart';
import '../../member/application/member_providers.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import 'widgets/routine_done_lumi_motion.dart';

/// 이룸이가 일과를 **다 끝냈을 때** 한 번 뜨는 화면 (Figma `일과완료` 1274:9831).
///
/// 카드 하나를 끝낼 때마다 뜨는 별 화면([RewardScreen])과 다르다. 마지막 카드의 별
/// 화면을 닫으면 이어서 이 화면이 뜨고, 닫으면 이룸이 홈으로 돌아간다.
///
/// 보호자가 정한 보상은 여기서 칩으로 보여 준다. **보상이 없으면 칩을 그리지 않는다** —
/// 제목과 버튼 자리는 시안 좌표에 고정이라 칩이 빠져도 나머지는 움직이지 않는다.
class RoutineDoneScreen extends ConsumerWidget {
  const RoutineDoneScreen({
    super.key,
    this.reward,
    this.isMotionEnabled = true,
  });

  /// 보호자가 정한 보상. 비면 칩을 그리지 않는다.
  final ({String emoji, String text})? reward;

  /// false 면 등장·대기 움직임을 모두 끄고 정지 모양만 그린다 (시험용. 시스템 동작 줄이기도 같게 처리).
  final bool isMotionEnabled;

  /// 시안 프레임에서 안전영역 윗변(상태바 아래)의 y. 시안 좌표에서 이 값을 빼서 놓는다.
  static const _safeTop = 59.0;

  /// 시안 프레임 좌표(x, y) → 안전영역 안 좌표. 그림은 가로세로를 같이 줄이려 `.w`로 통일한다.
  static double _x(double v) => v.w;
  static double _y(double v) => (v - _safeTop).w;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final space = context.space;
    final colors = context.colors;
    final reward = this.reward;
    final isMotionOn =
        isMotionEnabled && !MediaQuery.disableAnimationsOf(context);

    // 안내 문구의 호칭: 서버 닉네임 > 온보딩 이름 > 이룸이
    final localName = ref.watch(onboardingProvider).displayName;
    final childName = ref
        .watch(memberProvider)
        .maybeWhen(
          data: (member) => member?.nickname ?? localName,
          orElse: () => localName,
        );

    return Scaffold(
      // Figma linear-gradient(180deg, #0C0D1A 7% → #574D2B 100%)
      body: ChildNightSkyBackdrop(
        sky: ChildNightSky.routineDone,
        child: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 장식 — 별 다섯 개와 루미. 시안 절대좌표 그대로다.
              RoutineDoneLumiMotion(
                isMotionEnabled: isMotionEnabled,
                toDesignX: _x,
                toDesignY: _y,
              ),
              Column(
                children: [
                  // **`Spacer`가 아니다.** 남는 자리를 나누면 화면 높이에 따라 글자가
                  // 오르내려 시안과 어긋난다 (보상 화면과 같은 이유).
                  SizedBox(height: _y(395)),
                  _FadeIn(
                    isMotionOn: isMotionOn,
                    delay: AppMotion.emphasis,
                    child: Text(
                      context.l10n.routineDoneTitle,
                      style: context.typo.cardHeadline.copyWith(
                        color: colors.surface,
                      ),
                    ),
                  ),
                  // 제목(y395, 높이 30) → 안내(y441)
                  SizedBox(height: 16.h),
                  _FadeIn(
                    isMotionOn: isMotionOn,
                    delay: AppMotion.emphasis + AppMotion.sceneStagger,
                    child: Text(
                      context.l10n.routineDoneMessage(childName),
                      textAlign: TextAlign.center,
                      style: context.typo.cardDescription.copyWith(
                        color: colors.surface,
                      ),
                    ),
                  ),
                  if (reward != null) ...[
                    // 안내(y441, 높이 48) → 칩(y513)
                    SizedBox(height: 24.h),
                    _FadeIn(
                      isMotionOn: isMotionOn,
                      delay: AppMotion.emphasis + AppMotion.sceneStagger * 2,
                      child: _RewardChip(
                        text: reward.emoji.isEmpty
                            ? reward.text
                            : '${reward.emoji} ${reward.text}',
                      ),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      space.buttonMarginH,
                      0,
                      space.buttonMarginH,
                      // 버튼이 y675~741 이고 홈 인디케이터 21 을 빼면 90 이 남는다 (보상 화면과 같다).
                      90.h,
                    ),
                    child: _FadeIn(
                      isMotionOn: isMotionOn,
                      delay: AppMotion.emphasis + AppMotion.sceneStagger * 3,
                      child: ElumButton(
                        label: context.l10n.routineDoneButton,
                        backgroundColor: colors.rewardButton,
                        labelColor: colors.textPrimary,
                        // 일과를 다 끝냈으니 상세로 돌아갈 곳이 없다 — 홈으로 간다.
                        onPressed: () {
                          playChildHaptic(context, ChildHapticKind.tap);
                          context.go(Routes.child);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 보상 칩 (시안 `1291:10874` — 333×72, 모서리 8, `#EEE9E6` 30%, 글자 20/800 흰색).
///
/// 카드별 별 화면의 [RewardBanner]와 모양이 다르다(높이 48·`다하면` 문구).
/// 이 화면의 칩은 이미 다 했으니 **보상 문구만** 보여 준다.
class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 333.w,
      height: 72.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.routineTileBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        text,
        // 긴 보상은 두 줄까지 보이고 그 이상은 자른다 (명세 9-4).
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: context.typo.subtitle.copyWith(color: colors.surface),
      ),
    );
  }
}

/// 지연 후 나타나며 살짝 올라온다. 움직임이 꺼져 있으면 바로 보여 준다.
class _FadeIn extends StatelessWidget {
  const _FadeIn({
    required this.child,
    required this.delay,
    required this.isMotionOn,
  });

  final Widget child;
  final Duration delay;
  final bool isMotionOn;

  @override
  Widget build(BuildContext context) {
    if (!isMotionOn) return child;

    // 전체 시간 = 지연 + 나타나는 시간(slow). 지연만큼 기다렸다가 slow 동안 나타난다.
    final totalDuration = delay + AppMotion.slow;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: totalDuration,
      curve: Interval(
        delay.inMilliseconds / totalDuration.inMilliseconds,
        1,
        curve: AppMotion.entry,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
