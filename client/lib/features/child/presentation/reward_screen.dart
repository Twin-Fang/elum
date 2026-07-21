import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../guardian/data/routine_repository.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../domain/reward_character.dart';
import 'widgets/reward_star.dart';

/// Figma `아이_보상_루미`(309:4055) / `_포포`(334:4320) / `_루루`(343:4434).
///
/// 세 화면은 배경·별이 같고 **캐릭터와 문구만 다르다.** 매번 무작위로 고른다.
///
/// 어두운 배경을 쓰는 유일한 화면이다. 별이 빛나 보이려면 주변이 어두워야 한다.
/// 그래서 `AppColors`를 쓰지 않고 이 화면 전용 색을 둔다.
///
/// **강한 인터랙션을 허용하는 자리다.** 토스 원칙상 화려한 모션은 브랜드 핵심
/// 순간에만 쓰는데, 아이가 할 일을 해낸 순간이 바로 그것이다 (docs/motion.md).
class RewardScreen extends ConsumerStatefulWidget {
  const RewardScreen({super.key});

  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen> {
  /// 화면이 다시 그려져도 캐릭터가 바뀌지 않게 한 번만 뽑는다.
  late final RewardCharacter _character = RewardCharacter.pick();

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    // 문구에 아이 이름이 들어간다 (Figma 309:4055 · 343:4434).
    // 서버 닉네임이 우선이고, 없으면 온보딩에서 받은 이름을 쓴다.
    final localName = ref.watch(onboardingProvider).displayName;
    final childName = ref.watch(memberProvider).maybeWhen(
          data: (member) => member?.nickname ?? localName,
          orElse: () => localName,
        );

    return Scaffold(
      body: DecoratedBox(
        // Figma linear-gradient(180deg, #0C0D1A → #242634)
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.rewardBackdropTop, colors.rewardBackdropBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              const RewardStar(),
              SizedBox(height: space.xl),
              _FadeSlideIn(
                delay: AppMotion.normal,
                child: Text(
                  _character.title,
                  style: context.typo.cardHeadline
                      .copyWith(color: colors.surface),
                ),
              ),
              SizedBox(height: space.md),
              _FadeSlideIn(
                delay: AppMotion.slow,
                child: Text(
                  _character.messageFor(childName),
                  textAlign: TextAlign.center,
                  style: context.typo.cardDescription
                      .copyWith(color: colors.surface),
                ),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  space.buttonMarginH,
                  0,
                  space.buttonMarginH,
                  space.lg,
                ),
                child: _FadeSlideIn(
                  delay: AppMotion.slow,
                  child: ElumButton(
                    label: _character.buttonLabel,
                    backgroundColor: colors.rewardButton,
                    labelColor: colors.textPrimary,
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 지연 후 나타나며 살짝 올라온다.
///
/// 별이 먼저 터지고 문구가 뒤따라야 시선이 자연스럽게 흐른다.
class _FadeSlideIn extends StatelessWidget {
  const _FadeSlideIn({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    // 접근성 — 동작 줄이기를 켰으면 즉시 보여준다
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: Interval(
        // 전체 구간 중 delay만큼 지난 뒤부터 움직인다
        (delay.inMilliseconds / (AppMotion.slow.inMilliseconds * 2))
            .clamp(0.0, 0.9),
        1,
        curve: AppMotion.entry,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 16), child: child),
      ),
      child: child,
    );
  }
}
