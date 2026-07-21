import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/glowing_svg.dart';
import '../../guardian/data/routine_repository.dart';

/// Figma `아이_별`(364:8219) — 지금까지 모은 별을 보여준다.
///
/// 아이 홈의 별 배지를 탭하면 들어온다. 어두운 밤하늘 배경에 큰 별과
/// 누적 개수를 띄운다. 뒤로가기만 있다.
class ChildStarsScreen extends ConsumerWidget {
  const ChildStarsScreen({super.key});

  /// Figma 실측 — 주변 작은 별들의 (x, y, 크기, 불투명도).
  /// 393×852 기준 절대 좌표를 그대로 옮긴다 (Spacer 배분 금지 규칙).
  /// Figma 절대 y는 상태바(~52)를 포함한다. SafeArea 안에서는 그만큼 빼야
  /// 큰 별(182→130)·숫자·문구와 같은 기준으로 정렬된다.
  static const _statusBarH = 52.0;

  /// glow는 각 star_deco SVG에 내장된 feGaussianBlur 필터 색과 맞춘다.
  /// 1~6번은 초록, 7번만 보라다 (SVG 자체 색상 추출값, Figma effect 노드와 대조 완료).
  static const _decoStars = [
    (x: 54.0, y: 407.0, size: 38.0, opacity: 0.4, glow: _StarGlow.green),
    (x: 321.0, y: 356.0, size: 36.0, opacity: 0.8, glow: _StarGlow.green),
    (x: 319.0, y: 110.0, size: 43.0, opacity: 0.5, glow: _StarGlow.green),
    (x: 32.0, y: 196.0, size: 65.0, opacity: 1.0, glow: _StarGlow.green),
    (x: 216.0, y: 154.0, size: 43.0, opacity: 1.0, glow: _StarGlow.green),
    (x: 110.0, y: 107.0, size: 30.0, opacity: 0.3, glow: _StarGlow.green),
    (x: 286.0, y: 232.0, size: 30.0, opacity: 1.0, glow: _StarGlow.purple),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // 별 개수. 조회 실패해도 0으로 화면은 뜬다 (docs 원칙 6번)
    final stars = ref.watch(memberProvider).maybeWhen(
          data: (member) => member?.totalStars ?? 0,
          orElse: () => 0,
        );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Figma linear-gradient(180deg, #0C0D1A → #242634).
          // 보상 화면과 같은 밤하늘 세계관이라 토큰을 공유한다.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.rewardBackdropTop, colors.rewardBackdropBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // 주변 작은 별 — 그라데이션은 에셋, 글로우는 GlowingSvg로 재현한다
              // (flutter_svg가 SVG 내장 feGaussianBlur를 그리지 못한다)
              for (final (index, star) in _decoStars.indexed)
                Positioned(
                  left: star.x.w,
                  top: (star.y - _statusBarH).h,
                  child: Opacity(
                    opacity: star.opacity,
                    child: GlowingSvg(
                      assetPath: AppAssets.starDeco(index + 1),
                      size: star.size.w,
                      glowColor: star.glow == _StarGlow.green
                          ? colors.starDecoGlowGreen
                          : colors.starDecoGlowPurple,
                    ),
                  ),
                ),
              // 큰 별 (Figma x=47, y=182, 299×299)
              // blur(20px) 노란 후광(node 364:8283)을 haloBlur로 재현 (이슈 #107).
              Positioned(
                left: 47.w,
                top: 130.h,
                child: GlowingSvg(
                  assetPath: AppAssets.starBig,
                  size: 299.w,
                  glowColor: colors.rewardStarGlow,
                  haloBlur: 299.w * 0.06,
                  haloColor: colors.rewardStarHalo,
                ),
              ),
              // 누적 개수 (Figma y=481, 80/w800, 노랑→흰 그라데이션)
              Positioned(
                top: 440.h,
                left: 0,
                right: 0,
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [colors.starsNumberStart, colors.surface],
                    ).createShader(bounds),
                    child: Text(
                      '$stars',
                      style: context.typo.starsCount
                          .copyWith(color: colors.surface),
                    ),
                  ),
                ),
              ),
              // 안내 문구 (Figma y=594, 20/w400, 중앙)
              Positioned(
                top: 552.h,
                left: 0,
                right: 0,
                child: Text(
                  '$stars개의 별을 얻었어요\n할 일을 해내고 별을 더 찾아봐요!',
                  textAlign: TextAlign.center,
                  style: context.typo.cardDescription
                      .copyWith(color: colors.surface),
                ),
              ),
              // 뒤로가기 (Figma x=24, y=87 — SafeArea 안 상단)
              Positioned(
                left: 12.w,
                top: 12.h,
                child: AppPressable(
                  onTap: () => context.pop(),
                  scaleDown: AppPressable.scaleIcon,
                  // 아동 모드 터치 타겟(64) 확보
                  child: SizedBox(
                    width: 64.w,
                    height: 64.w,
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.iconBack,
                        width: 24.w,
                        height: 24.w,
                        colorFilter: ColorFilter.mode(
                          colors.surface,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
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

/// star_deco SVG가 내장한 feGaussianBlur 필터 색 — 초록 6개, 보라 1개뿐이다.
enum _StarGlow { green, purple }
