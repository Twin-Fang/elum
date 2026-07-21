import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_fade_slide_in.dart';
import '../../../core/widgets/elum_button.dart';
import '../application/onboarding_notifier.dart';

/// Figma `시작` (238:1808) — 서비스 진입 화면.
///
/// 좌표·크기는 Figma 값(393×852 기준)을 그대로 쓰되 `.w`/`.h`/`.sp`로 감싼다.
/// ScreenUtil이 실제 화면 크기에 맞춰 비례 변환하므로 기기가 달라져도 구도가 유지된다.
///
/// ## 연출 (설계: docs/superpowers/specs/2026-07-22-onboarding-animation-design.md)
///
/// 장면(병아리·덤불·별·실루엣·배경)은 **첫 프레임부터 완성돼 있다** —
/// 뒤늦게 뜨면 덜 로드된 느낌이 난다. 그 위에 문구 → 로고 → CTA만
/// [AppMotion.sceneStagger] 간격으로 차분하게 등장한다.
///
/// 등장 후에는 병아리 숨쉬기·별 반짝임 idle 모션이 돈다. OS "동작 줄이기"가
/// 켜져 있으면 idle은 시작하지 않는다 (motion.md §접근성).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// idle 주기 — 이 화면 전용 안무 값이라 AppMotion에 두지 않는다.
  /// 서로 배수가 아니게 잡아 두 모션이 같은 자리로 돌아와 패턴이
  /// 눈에 보이는 것을 피한다 (motion.md §성능).
  static const _breathPeriod = Duration(milliseconds: 3400);
  static const _twinklePeriod = Duration(milliseconds: 2600);

  late final AnimationController _breath;
  late final AnimationController _twinkle;
  bool _idleStarted = false;

  @override
  void initState() {
    super.initState();
    // 시작은 didChangeDependencies에서 — 동작 줄이기 설정을 먼저 봐야 한다
    _breath = AnimationController(vsync: this, duration: _breathPeriod);
    _twinkle = AnimationController(vsync: this, duration: _twinklePeriod);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion && !_idleStarted) {
      _idleStarted = true;
      _breath.repeat(reverse: true);
      _twinkle.repeat(reverse: true);
    } else if (reduceMotion && _idleStarted) {
      // 설정이 켜지면 즉시 정지하고 원래 상태로 되돌린다
      _idleStarted = false;
      _breath
        ..stop()
        ..value = 0;
      _twinkle
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 이미 온보딩을 마쳤으면 다시 묻지 않는다
    final isDone = ref.read(localStorageProvider).isOnboardingCompleted;

    return Scaffold(
      body: Container(
        // 배경: 흰색 → 크림 (Figma linear-gradient 180deg, 40% 지점)
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.splashTop, colors.splashBottom],
            stops: const [0, 0.4],
          ),
        ),
        child: Stack(
          children: [
            // 병아리 몸통 — Figma y=413, 393×439.
            // 둥근 path와 방사형 그라데이션이 SVG 안에 있다.
            // 직접 그리면 사각형이 되므로 반드시 에셋을 쓴다.
            Positioned(
              left: 0,
              top: 413.h,
              width: 393.w,
              // 숨쉬기 — 바닥에 앉은 채 위로만 살짝 부풀어야 자연스럽다
              child: RepaintBoundary(
                child: ScaleTransition(
                  key: const ValueKey('splash-chick-breath'),
                  alignment: Alignment.bottomCenter,
                  scale: Tween<double>(begin: 1, end: 1.015)
                      .chain(CurveTween(curve: AppMotion.standard))
                      .animate(_breath),
                  child: SvgPicture.asset(
                    AppAssets.splashChickBody,
                    width: 393.w,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ),

            // 덤불 (x=184, y=308, 113×111)
            Positioned(
              left: 184.w,
              top: 308.h,
              child: SvgPicture.asset(AppAssets.splashHill, width: 113.w),
            ),

            // 반짝이는 별 (x=281, y=340, 36×34)
            Positioned(
              left: 281.w,
              top: 340.h,
              child: RepaintBoundary(
                child: FadeTransition(
                  key: const ValueKey('splash-star-twinkle'),
                  opacity: Tween<double>(begin: 1, end: 0.55)
                      .chain(CurveTween(curve: AppMotion.standard))
                      .animate(_twinkle),
                  child: SvgPicture.asset(AppAssets.splashStar, width: 36.w),
                ),
              ),
            ),

            // 언덕 위 캐릭터 실루엣 (각 30×32, y=573)
            Positioned(
              left: 124.w,
              top: 573.h,
              child: SvgPicture.asset(AppAssets.splashCharLeft, width: 30.w),
            ),
            Positioned(
              left: 239.w,
              top: 573.h,
              child: SvgPicture.asset(AppAssets.splashCharRight, width: 30.w),
            ),
            Positioned(
              left: 174.w,
              top: 599.h,
              child: SvgPicture.asset(AppAssets.splashCenter, width: 45.w),
            ),

            // 문구 (x=141 y=140 / x=92 y=168) — 가로 중앙 정렬, 함께 등장
            Positioned(
              left: 0,
              top: 140.h,
              width: 393.w,
              child: AppFadeSlideIn(
                child: Text(
                  '오늘의 하루,',
                  textAlign: TextAlign.center,
                  style: context.typo.subtitle.copyWith(
                    color: colors.textSecondary,
                    fontSize: 20.sp,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 168.h,
              width: 393.w,
              child: AppFadeSlideIn(
                child: Text(
                  '차근차근 함께해요',
                  textAlign: TextAlign.center,
                  style: context.typo.headline.copyWith(
                    color: colors.splashTitle,
                    fontSize: 26.sp,
                  ),
                ),
              ),
            ),

            // 로고 (x=115, y=214, 164×60) — 폰트가 아니라 SVG다. 문구 다음에 등장.
            Positioned(
              left: 115.w,
              top: 214.h,
              child: AppFadeSlideIn(
                delay: AppMotion.sceneStagger,
                child: SvgPicture.asset(AppAssets.logo, width: 164.w),
              ),
            ),

            // 하단 CTA (x=16, y=675, 360×66) — 마지막에 등장
            Positioned(
              left: 16.w,
              top: 675.h,
              width: 360.w,
              child: AppFadeSlideIn(
                delay: AppMotion.sceneStagger * 2,
                child: ElumButton(
                  label: '시작하기',
                  onPressed: () {
                    // GoRouter를 명시적으로 찾아서 호출한다.
                    // context.go()만으로는 DevToolsOverlay 레이어에서 라우터를 찾지 못한다.
                    try {
                      GoRouter.of(context).go(
                        isDone ? Routes.guardian : Routes.onboardingName,
                      );
                    } catch (e) {
                      // 라우터를 찾지 못한 경우(테스트 환경 등)
                      debugPrint('라우팅 실패: $e');
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
