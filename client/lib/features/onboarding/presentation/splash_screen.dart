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
/// 등장 후에는 머리 위 새싹 줄기와 청록 구슬만 아주 살짝 상하로 부유한다.
/// 병아리 몸은 고정한다(흔들리면 눈·코까지 우글거려 어색하다). OS "동작
/// 줄이기"가 켜져 있으면 부유는 시작하지 않는다 (motion.md §접근성).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// 부유(bob) 주기 — 이 화면 전용 안무 값이라 AppMotion에 두지 않는다.
  /// 장면 전체가 아주 느리게 상하로 떠다니게 해 정지 화면이 아니게만 한다.
  static const _floatPeriod = Duration(milliseconds: 3600);

  late final AnimationController _float;
  bool _idleStarted = false;

  @override
  void initState() {
    super.initState();
    // 시작은 didChangeDependencies에서 — 동작 줄이기 설정을 먼저 봐야 한다
    _float = AnimationController(vsync: this, duration: _floatPeriod);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion && !_idleStarted) {
      _idleStarted = true;
      _float.repeat(reverse: true);
    } else if (reduceMotion && _idleStarted) {
      // 설정이 켜지면 즉시 정지하고 원래 상태로 되돌린다
      _idleStarted = false;
      _float
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  /// 장면 요소를 아주 미세하게 상하로 부유시킨다.
  ///
  /// 요소마다 [phase](0~1)를 어긋나게 주면 병아리·줄기·실루엣이 같은 위상으로
  /// 함께 오르내리지 않아 더 살아 보인다. 진폭은 화면 높이에 비례([.h]).
  Widget _floating({
    required double phase,
    required Widget child,
    Key? key,
  }) {
    return AnimatedBuilder(
      key: key,
      animation: _float,
      builder: (context, child) {
        // 삼각파(0→1→0)를 위상만큼 밀어 요소별로 다른 지점에서 움직이게 한다
        final t = ((_float.value + phase) % 1.0);
        final wave = (0.5 - (t - 0.5).abs()) * 2; // 0..1..0
        final dy = (wave - 0.5) * 6.h; // ±3.h 만큼 부유
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: child,
    );
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
            // 병아리는 고정한다 — 몸이 흔들리면 눈·코까지 우글거려 어색하다.
            Positioned(
              left: 0,
              top: 413.h,
              width: 393.w,
              child: SvgPicture.asset(
                AppAssets.splashChickBody,
                width: 393.w,
                fit: BoxFit.fitWidth,
              ),
            ),

            // 새싹 줄기 (x=184, y=308, 113×111) — 끝의 구슬과 함께 부유한다.
            Positioned(
              left: 184.w,
              top: 308.h,
              child: _floating(
                key: const ValueKey('splash-stem-float'),
                phase: 0,
                child: SvgPicture.asset(AppAssets.splashHill, width: 113.w),
              ),
            ),

            // 청록 구슬 (x=281, y=340, 36×34) — 새싹 줄기 끝.
            //
            // glow는 코드로 그린다. 구슬 SVG 안에 Figma가 넣어둔 feGaussianBlur
            // 필터가 있지만 flutter_svg 2.3.0이 SVG <filter>를 렌더하지 못해
            // (테스트 로그 `unhandled element <filter/>`) glow가 통째로 사라진다.
            // 원 도형은 규칙대로 SVG를 그대로 쓰고, glow만 BoxShadow로 재현한다.
            // Figma effect_WJJJ2E: 0 offset · blur 30 · rgba(0,255,208).
            Positioned(
              left: 281.w,
              top: 340.h,
              child: RepaintBoundary(
                // 구슬은 줄기 끝에 달렸으니 줄기와 같은 위상으로 함께 뜬다
                child: _floating(
                  phase: 0,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // glow — 구슬 원 뒤에 깐다. 원본은 구슬 지름의 두어 배로
                      // 진하고 넓게 퍼진다. 안쪽(진하게)·바깥쪽(넓게) 두 겹으로
                      // 쌓아 그 느낌을 낸다. Figma effect_WJJJ2E 계열 색(rgba
                      // 0,255,208)을 쓴다. blur·spread는 화면 크기에 비례([.w]).
                      Container(
                        width: 20.w,
                        height: 20.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            // 안쪽 — 구슬에 밀착된 진한 코어
                            BoxShadow(
                              color: colors.splashOrbGlowCore,
                              blurRadius: 18.w,
                              spreadRadius: 4.w,
                            ),
                            // 바깥쪽 — 넓게 번지는 옅은 헤일로
                            BoxShadow(
                              color: colors.splashOrbGlowHalo,
                              blurRadius: 34.w,
                              spreadRadius: 10.w,
                            ),
                          ],
                        ),
                      ),
                      SvgPicture.asset(AppAssets.splashStar, width: 36.w),
                    ],
                  ),
                ),
              ),
            ),

            // 언덕 위 캐릭터 실루엣 (각 30×32, y=573) — 고정.
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
