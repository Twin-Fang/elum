import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'app_fade_slide_in.dart';

/// 시작 화면의 그림 한 벌 (Figma `시작` 238:1808).
///
/// 좌표·크기는 Figma 값(393×852 기준)을 그대로 쓰되 `.w`/`.h`/`.sp`로 감싼다.
/// ScreenUtil이 실제 화면 크기에 맞춰 비례 변환하므로 기기가 달라져도 구도가 유지된다.
///
/// **시작 화면과 로그인 화면이 이 한 벌을 공유한다** (이슈 #207).
/// `시작하기` 버튼을 없애면서 두 화면이 사실상 같은 장면이 됐다. 그림을 복사해
/// 두 벌 두면 한쪽만 고쳐져 조용히 어긋나므로 위젯 하나로 묶었다.
///
/// ## 연출 (설계: docs/superpowers/specs/2026-07-22-onboarding-animation-design.md)
///
/// 장면(병아리·줄기·구슬·배경)은 **첫 프레임부터 완성돼 있다** —
/// 뒤늦게 뜨면 덜 로드된 느낌이 난다. 그 위에 문구 → 로고만
/// [AppMotion.sceneStagger] 간격으로 차분하게 등장한다.
///
/// 등장 후에는 머리 위 새싹 줄기와 청록 구슬만 아주 살짝 상하로 부유한다.
/// 병아리 몸은 고정한다 — 화면의 절반을 차지해 조금만 움직여도 눈에 걸린다.
/// OS "동작 줄이기"가 켜져 있으면 부유는 시작하지 않는다 (motion.md §접근성).
class SplashScene extends StatefulWidget {
  const SplashScene({super.key, this.overlay, this.showFace = true});

  /// 그림 위에 얹을 것. 로그인 화면은 여기에 제공자 버튼을 넣는다.
  final Widget? overlay;

  /// 병아리 **얼굴**(눈 둘 + 부리)을 그릴지.
  ///
  /// 시안(`238:1808`)은 병아리가 **뒤를 돌아본** 모습이라 얼굴이 없고 머리 위
  /// 새싹도 반대쪽으로 갔다. 그 시안은 버튼이 셋인 iOS 기준이다.
  ///
  /// **안드로이드는 애플 버튼이 없어 버튼이 둘뿐이고, 그만큼 자리가 남아
  /// 얼굴을 살린다.** 그래서 이 값은 호출하는 쪽이 정한다 — 애플 버튼을
  /// 그리는 화면은 `false`를 준다 (#297).
  final bool showFace;

  /// 이 기기에서 얼굴을 그리는가 — **애플 버튼이 없는 쪽에서만 그린다.**
  ///
  /// 시작 화면은 버튼이 없어 얼굴이 가려질 일이 없지만, iOS 에서 시작 →
  /// 로그인으로 넘어갈 때 얼굴이 깜빡 사라지면 어색하다. 두 화면이 같은
  /// 그림을 쓰므로(#207) 기준을 하나로 맞춘다.
  static bool get faceShowsOnThisPlatform => !Platform.isIOS;

  @override
  State<SplashScene> createState() => _SplashSceneState();
}

class _SplashSceneState extends State<SplashScene>
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
    return Container(
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
          // 직접 그리면 사각형이 되므로 반드시 에셋을 쓴다. 고정한다.
          // **크기를 둘 다 준다.** 폭만 주고 `fitWidth`로 두면 상자 높이가
          // 그림 픽셀 높이로 잡혀 세로가 0.77배로 눌린다 — 몸이 33 짧아 보였다 (#297).
          Positioned(
            left: 0,
            top: 413.h,
            width: 393.w,
            height: 439.h,
            child: Image.asset(
              AppAssets.splashChickBody,
              width: 393.w,
              height: 439.h,
              fit: BoxFit.fill,
            ),
          ),

          // 새싹 줄기 (x=87, y=308, 113×111) — 끝의 구슬과 함께 부유한다.
          // **x가 184가 아니다.** 시안(`726:4742`)은 87이고, 184로 두면 줄기가
          // 화면 오른쪽으로 거울상처럼 뒤집혀 보인다 (#297).
          Positioned(
            left: 87.w,
            top: 308.h,
            child: _floating(
              key: const ValueKey('splash-stem-float'),
              phase: 0,
              child: SvgPicture.asset(AppAssets.splashHill, width: 113.w),
            ),
          ),

          // 청록 구슬 (본체 x=67, y=340, 36×34) — 새싹 줄기 끝.
          //
          // **그림 하나로 그린다.** 둘레 빛이 SVG `<filter>`라 렌더러가 버려
          // 전에는 원만 남고 빛을 BoxShadow로 흉내 내고 있었다. 게다가 상자(96×94)에
          // 본체 크기(36)를 줘서 **구슬이 13으로 쪼그라들어 있었다** (#297).
          // 빛이 구워진 PNG를 상자 크기 그대로 놓는다 — 본체가 (30,30)에 있으므로
          // 상자는 (67-30, 340-30)에 온다.
          Positioned(
            left: 37.w,
            top: 310.h,
            child: RepaintBoundary(
              // 구슬은 줄기 끝에 달렸으니 줄기와 같은 위상으로 함께 뜬다
              child: _floating(
                phase: 0,
                child: Image.asset(AppAssets.splashOrb, width: 96.w),
              ),
            ),
          ),

          // 병아리 얼굴 — 눈 둘(각 30×32, y=573)과 부리(45×25, y=599). 고정.
          //
          // **애플 버튼이 뜨는 화면에서는 그리지 않는다** ([showFace]).
          // 버튼이 셋이면 카카오 버튼이 545~611을 덮는데 부리가 624까지 내려와
          // **버튼과 버튼 사이로 주황 조각이 13 삐져나온다** (#297).
          if (widget.showFace) ...[
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
          ],

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

          // **하단 페이드를 두지 않는다.** 전에는 버튼 아래를 크림색으로 덮어
          // 부드럽게 이었는데, 시안(`238:1808`) 덤프에는 그런 사각형이 없다.
          // 덮어 두니 병아리 아래쪽 민트가 크림빛으로 지워져 몸이 짧아 보였다 (#297).

          // 화면별로 얹는 것 — 로그인 버튼 등. 항상 맨 위에 그린다.
          if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
        ],
      ),
    );
  }
}
