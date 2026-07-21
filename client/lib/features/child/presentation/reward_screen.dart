import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
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
  const RewardScreen({super.key, this.character});

  /// 보여줄 캐릭터. 비우면 **무작위로 뽑는다**(실제 동작).
  ///
  /// 테스트에서만 고정한다 — 골든이 실행마다 달라지면 회귀를 못 잡는다.
  final RewardCharacter? character;

  @override
  ConsumerState<RewardScreen> createState() => _RewardScreenState();
}

class _RewardScreenState extends ConsumerState<RewardScreen> {
  /// 화면이 다시 그려져도 캐릭터가 바뀌지 않게 한 번만 뽑는다.
  late final RewardCharacter _character =
      widget.character ?? RewardCharacter.pick();

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
              _RewardHero(character: _character),
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

/// 큰 별 + 별에 앉은 캐릭터 + 바닥 그림자.
///
/// Figma에서 큰 별(Group 46)은 (62,125) 269×269인데 코드의 별은 209라,
/// 캐릭터·그림자의 Figma 절대좌표를 별 박스 기준 상대좌표로 옮긴 뒤
/// 같은 비율로 줄여 별 하단 중앙에 정확히 겹치게 한다.
class _RewardHero extends StatelessWidget {
  const _RewardHero({required this.character});

  final RewardCharacter character;

  /// Figma 큰 별 박스 한 변(269). 코드 별(209)과의 비례 환산 기준.
  static const _figmaStarSize = 269.0;
  static const _scale = RewardStar.mainSize / _figmaStarSize;

  /// Figma 절대좌표(393×852)에서의 별 박스 원점.
  static const _starOriginX = 62.0;
  static const _starOriginY = 125.0;

  /// 바닥 그림자 (Figma `Ellipse 23` — x162 y430, 65×16).
  static const _shadowFrame = (x: 162.0, y: 430.0, w: 65.0, h: 16.0);

  /// 별만 위로 끌어올리는 양. Figma는 별 하단이 캐릭터 머리에 거의 닿아
  /// 겹쳐 보인다. 별만 이만큼 올려 간격을 확보한다 — 캐릭터는 그대로다
  /// (이슈 #107). blur 후광까지 감안한 실측값이다.
  static const _starLift = 28.0;

  /// 캐릭터 실측 배치 (Figma 절대좌표).
  /// 포포는 레이아웃 박스(131.06, 321) 122.65×118의 중앙에 실측 117×104가 들어간다.
  ({double x, double y, double w, double h}) get _charFrame =>
      switch (character) {
        RewardCharacter.lumi => (x: 131.06, y: 325, w: 124.7, h: 114),
        RewardCharacter.popo => (x: 133.89, y: 328, w: 117, h: 104),
        RewardCharacter.ruru => (x: 131.06, y: 341.44, w: 122.7, h: 97.6),
      };

  @override
  Widget build(BuildContext context) {
    final char = _charFrame;
    // Figma 절대좌표 → 별 박스 상대좌표 → 코드 별 크기로 비례 환산
    double sx(double v) => (v - _starOriginX) * _scale;
    double sy(double v) => (v - _starOriginY) * _scale;

    // 그림자 하단이 별 박스보다 아래로 나온 만큼 높이를 늘린다.
    // 여기에 별을 위로 올린 만큼(_starLift)을 더해 위 공간을 확보한다 —
    // 별은 Stack 최상단(top:0)에 두고, 그림자·캐릭터를 _starLift만큼 내려
    // 화면상 제자리에 두면 결과적으로 별만 위로 올라간다 (이슈 #107).
    final height =
        (sy(_shadowFrame.y) + _shadowFrame.h * _scale + _starLift)
            .clamp(RewardStar.mainSize + _starLift, double.infinity);

    // 캐릭터가 별 위에 앉은 구도라 세로도 .w로 통일한다 —
    // .h를 섞으면 화면비가 다른 기기에서 캐릭터가 별에서 떨어진다
    return SizedBox(
      width: RewardStar.mainSize.w,
      height: height.w,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // z순서는 Figma 레이어 순서 그대로 — 그림자 → 별 → 캐릭터.
          // 그림자·캐릭터는 별을 올린 만큼(_starLift) 내려 화면상 제자리를 지킨다.
          Positioned(
            left: sx(_shadowFrame.x).w,
            top: (sy(_shadowFrame.y) + _starLift).w,
            child: _FadeSlideIn(
              delay: AppMotion.normal,
              child: ClipOval(
                child: SizedBox(
                  width: (_shadowFrame.w * _scale).w,
                  height: (_shadowFrame.h * _scale).w,
                  child: ColoredBox(color: context.colors.rewardGroundShadow),
                ),
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, child: RewardStar()),
          Positioned(
            left: sx(char.x).w,
            top: (sy(char.y) + _starLift).w,
            child: _FadeSlideIn(
              delay: AppMotion.normal,
              child: SvgPicture.asset(
                AppAssets.rewardCharacter(character),
                width: (char.w * _scale).w,
                height: (char.h * _scale).w,
              ),
            ),
          ),
        ],
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
