import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';
import '../theme/app_motion.dart';
import '../theme/theme_context_ext.dart';
import 'app_fade_slide_in.dart';

/// 로그인 장면의 배치값 한 벌. Figma 좌표(393×852)를 그대로 담는다.
///
/// **시안이 플랫폼별로 따로 나왔다** (이슈 #338). 좌표를 코드에 두 벌 복사하면
/// 한쪽만 고쳐져 조용히 어긋나므로 값만 갈아끼운다.
@immutable
class LoginSceneLayout {
  const LoginSceneLayout({
    required this.stemAsset,
    required this.stemLeft,
    required this.stemTop,
    required this.orbLeft,
    required this.orbTop,
    required this.bodyAsset,
    required this.bodyLeft,
    required this.bodyTop,
    required this.bodyHeight,
    required this.captionTop,
    required this.titleTop,
    required this.logoTop,
    this.face,
  });

  /// 새싹 줄기. 두 시안이 **거울상**이라 파일부터 다르다.
  final String stemAsset;
  final double stemLeft;
  final double stemTop;

  /// 구슬 **상자**의 왼쪽 위. 빛까지 구운 PNG라 본체(36×34)가 상자 안 (30, 30)에
  /// 있다 — 시안이 말하는 본체 자리에서 30씩 빼서 넣는다.
  final double orbLeft;
  final double orbTop;

  /// 병아리 몸통. 시안마다 높이가 달라 파일도 따로다.
  final String bodyAsset;
  final double bodyLeft;
  final double bodyTop;
  final double bodyHeight;

  /// `오늘의 하루,` · `차근차근 함께해요` · 로고의 y.
  final double captionTop;
  final double titleTop;
  final double logoTop;

  /// 병아리 얼굴. **얼굴이 없는 배치는 `null`이다.**
  final LoginSceneFace? face;

  /// iOS 시안 `238:1808` — 뒤를 돌아본 병아리.
  ///
  /// 얼굴이 없고 새싹이 왼쪽으로 휜다. 애플 버튼이 있어 버튼이 셋이라
  /// 자리가 모자라고, 얼굴을 그리면 카카오·네이버 버튼 **사이로 부리가
  /// 13 삐져나온다** (#297).
  static const ios = LoginSceneLayout(
    stemAsset: AppAssets.splashHill,
    stemLeft: 87,
    stemTop: 308,
    orbLeft: 37, // 본체 (67, 340)
    orbTop: 310,
    bodyAsset: AppAssets.splashChickBody,
    bodyLeft: 0,
    bodyTop: 413,
    bodyHeight: 439,
    captionTop: 140,
    titleTop: 168,
    logoTop: 214,
  );

  /// 안드로이드 시안 `1022:4333` — 앞을 보는 병아리.
  ///
  /// 얼굴이 있고 새싹이 오른쪽으로 휜다. 애플 버튼이 없어 버튼이 둘뿐이라
  /// 자리가 남는다. 그림 전체가 iOS보다 **위로 올라가고 커졌다.**
  static const android = LoginSceneLayout(
    stemAsset: AppAssets.splashHillAos,
    stemLeft: 183.5,
    stemTop: 265,
    orbLeft: 250.5, // 본체 (280.5, 297)
    orbTop: 267,
    bodyAsset: AppAssets.splashChickBodyAos,
    bodyLeft: -0.5,
    bodyTop: 370,
    bodyHeight: 481.53,
    captionTop: 103.7,
    titleTop: 131.7,
    logoTop: 177.7,
    face: LoginSceneFace(
      eyeLeft: 123.5,
      eyeRight: 238.5,
      eyeTop: 530,
      beakLeft: 173.5,
      beakTop: 556,
    ),
  );

  /// 이 기기가 따르는 배치.
  ///
  /// **애플 버튼 유무와 같은 기준으로 갈린다** — 시안이 그렇게 나뉘어 나왔다.
  static LoginSceneLayout get ofThisPlatform =>
      Platform.isIOS ? ios : android;
}

/// 병아리 얼굴 자리 (눈 둘 + 부리). 좌표는 Figma `1022:4333` 실측.
@immutable
class LoginSceneFace {
  const LoginSceneFace({
    required this.eyeLeft,
    required this.eyeRight,
    required this.eyeTop,
    required this.beakLeft,
    required this.beakTop,
  });

  final double eyeLeft;
  final double eyeRight;
  final double eyeTop;
  final double beakLeft;
  final double beakTop;
}

/// 로그인 화면의 그림 한 벌.
///
/// 좌표·크기는 Figma 값(393×852 기준)을 그대로 쓰되 `.w`/`.h`/`.sp`로 감싼다.
/// ScreenUtil이 실제 화면 크기에 맞춰 비례 변환하므로 기기가 달라져도 구도가 유지된다.
///
/// **한때 시작 화면과 이 그림을 공유했다** (이슈 #207). 새 시안에서 시작 화면이
/// 로고 한 장으로 줄면서 갈라졌다 (이슈 #338) — 그래서 이름이 `SplashScene`에서
/// 바뀌었다.
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
class LoginScene extends StatefulWidget {
  const LoginScene({super.key, this.overlay, LoginSceneLayout? layout})
    : _layout = layout;

  /// 그림 위에 얹을 것. 로그인 화면은 여기에 제공자 버튼을 넣는다.
  final Widget? overlay;

  /// 따를 배치. 시험이 두 시안을 모두 그려 볼 수 있게 열어 둔다.
  final LoginSceneLayout? _layout;

  LoginSceneLayout get layout => _layout ?? LoginSceneLayout.ofThisPlatform;

  @override
  State<LoginScene> createState() => _LoginSceneState();
}

class _LoginSceneState extends State<LoginScene> with TickerProviderStateMixin {
  /// 부유(bob) 주기 — 이 화면 전용 안무 값이라 AppMotion에 두지 않는다.
  /// 장면 전체가 아주 느리게 상하로 떠다니게 해 정지 화면이 아니게만 한다.
  static const _floatPeriod = Duration(milliseconds: 3600);

  /// 구슬 PNG 상자 폭 (빛 포함 96×94). 본체는 그 안 (30, 30)에 있다.
  static const _orbBoxWidth = 96.0;

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
  /// 요소마다 [phase](0~1)를 어긋나게 주면 같은 위상으로 함께 오르내리지 않아
  /// 더 살아 보인다. 진폭은 화면 높이에 비례([.h]).
  Widget _floating({required double phase, required Widget child, Key? key}) {
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
    final layout = widget.layout;
    final face = layout.face;

    return Container(
      // 배경: 흰색 → 크림 (Figma linear-gradient 180deg, 40% 지점). 두 시안이 같다.
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
          // 병아리 몸통 — 둥근 path와 방사형 그라데이션이 파일 안에 있다.
          // 직접 그리면 사각형이 되므로 반드시 에셋을 쓴다. 고정한다.
          //
          // **크기를 둘 다 준다.** 폭만 주고 `fitWidth`로 두면 상자 높이가
          // 그림 픽셀 높이로 잡혀 세로가 눌린다 — 몸이 33 짧아 보였다 (#297).
          Positioned(
            left: layout.bodyLeft.w,
            top: layout.bodyTop.h,
            width: 393.w,
            height: layout.bodyHeight.h,
            child: Image.asset(
              layout.bodyAsset,
              width: 393.w,
              height: layout.bodyHeight.h,
              fit: BoxFit.fill,
            ),
          ),

          // 새싹 줄기 (113×111) — 끝의 구슬과 함께 부유한다.
          Positioned(
            left: layout.stemLeft.w,
            top: layout.stemTop.h,
            child: _floating(
              key: const ValueKey('splash-stem-float'),
              phase: 0,
              child: SvgPicture.asset(layout.stemAsset, width: 113.w),
            ),
          ),

          // 청록 구슬 — 새싹 줄기 끝.
          //
          // **그림 하나로 그린다.** 둘레 빛이 SVG `<filter>`라 렌더러가 버려
          // 전에는 원만 남고 빛을 BoxShadow로 흉내 내고 있었다. 게다가 상자(96×94)에
          // 본체 크기(36)를 줘서 **구슬이 13으로 쪼그라들어 있었다** (#297).
          Positioned(
            left: layout.orbLeft.w,
            top: layout.orbTop.h,
            child: RepaintBoundary(
              // 구슬은 줄기 끝에 달렸으니 줄기와 같은 위상으로 함께 뜬다
              child: _floating(
                phase: 0,
                child: Image.asset(AppAssets.splashOrb, width: _orbBoxWidth.w),
              ),
            ),
          ),

          // 병아리 얼굴 — 눈 둘(각 30×32)과 부리(45×25). 고정.
          //
          // **얼굴이 있는 배치에서만 그린다.** iOS 시안은 병아리가 뒤를 돌아봐
          // 얼굴 자체가 없고, 그려 넣으면 버튼 사이로 부리가 삐져나온다 (#297).
          if (face != null) ...[
            Positioned(
              left: face.eyeLeft.w,
              top: face.eyeTop.h,
              child: SvgPicture.asset(AppAssets.splashCharLeft, width: 30.w),
            ),
            Positioned(
              left: face.eyeRight.w,
              top: face.eyeTop.h,
              child: SvgPicture.asset(AppAssets.splashCharRight, width: 30.w),
            ),
            Positioned(
              left: face.beakLeft.w,
              top: face.beakTop.h,
              child: SvgPicture.asset(AppAssets.splashCenter, width: 45.w),
            ),
          ],

          // 문구 — 가로 중앙 정렬, 함께 등장.
          // 두 시안 모두 문구 묶음의 중심이 화면 중앙(196.5)이라 좌표는 y만 다르다.
          Positioned(
            left: 0,
            top: layout.captionTop.h,
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
            top: layout.titleTop.h,
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

          // 로고 (x=115, 164×60) — 폰트가 아니라 SVG다. 문구 다음에 등장.
          Positioned(
            left: 115.w,
            top: layout.logoTop.h,
            child: AppFadeSlideIn(
              delay: AppMotion.sceneStagger,
              child: SvgPicture.asset(AppAssets.logo, width: 164.w),
            ),
          ),

          // **하단 페이드를 두지 않는다.** 전에는 버튼 아래를 크림색으로 덮어
          // 부드럽게 이었는데, 시안 덤프에는 그런 사각형이 없다. 덮어 두니
          // 병아리 아래쪽 민트가 크림빛으로 지워져 몸이 짧아 보였다 (#297).

          // 화면별로 얹는 것 — 로그인 버튼 등. 항상 맨 위에 그린다.
          if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
        ],
      ),
    );
  }
}
