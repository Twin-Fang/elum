import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/app_destination.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/storage/local_storage.dart';

/// Figma `스플래시` (1022:4415) — 서비스 진입 화면.
///
/// 그림은 [_SplashCanvas]가 그린다. 이 화면은 **언제 어디로 넘길지**만 맡는다.
///
/// **로그인 화면과 그림을 나눠 가진다** (이슈 #338). 한때 둘이 같은 장면을
/// 공유했는데(#207), 새 시안에서 시작 화면이 로고 한 장으로 줄면서 갈라졌다.
///
/// 시작 화면을 건너뛸지 판단한다.
///
/// 이미 로그인했고 온보딩도 끝났다면 갈 곳이 하나로 정해져 있다. 그런데도 버튼을
/// 한 번 더 누르게 하면, 매일 여는 사용자에게 의미 없는 탭이 계속 쌓인다.
@visibleForTesting
bool shouldSkipSplash({
  required bool hasSession,
  required bool onboardingCompleted,
  bool isElumiDevice = false,
}) => hasSession && (onboardingCompleted || isElumiDevice);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  /// 연출이 자리를 잡을 만큼만 기다린다. 더 길면 기다리는 화면이 된다.
  static const _autoAdvanceAfter = Duration(milliseconds: 1700);

  Timer? _advance;

  @override
  void initState() {
    super.initState();

    // 갈 곳이 정해진 사용자는 이 화면에 머물 이유가 없다.
    // build가 아니라 첫 프레임 뒤에 옮긴다 — 빌드 도중 라우팅하면 예외가 난다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storage = ref.read(localStorageProvider);
      final skip = shouldSkipSplash(
        hasSession: ref.read(authRepositoryProvider).hasSession,
        onboardingCompleted: storage.isOnboardingCompleted,
        isElumiDevice: storage.isElumiDevice,
      );
      if (skip) {
        _goTo(_destination());
        return;
      }
      // 처음 오는 사람은 연출을 보고 **저절로** 다음 화면으로 넘어간다 (이슈 #207).
      //
      // 예전에는 여기에 `시작하기` 버튼이 있었다. 누를 것이 하나뿐인 화면은
      // 다음에 뭐가 나오는지 말해 주지 않으면서 한 번 더 누르게만 만든다.
      _advance = Timer(_autoAdvanceAfter, () {
        if (!mounted) return;
        _goTo(_destination());
      });
    });
  }

  String _destination() => homeFor(ProviderScope.containerOf(context, listen: false));

  /// context.go()만으로는 DevToolsOverlay 레이어에서 라우터를 찾지 못한다.
  void _goTo(String route) {
    try {
      final router = GoRouter.of(context);
      // 연결 암호 넣기는 **뒤로 갈 수 있어야 한다** (이슈 #212). go로 바로 띄우면
      // 스택이 비어 pop이 실패하므로, 돌아갈 화면을 깔고 그 위에 얹는다 (#542).
      if (route == Routes.linkEnter) {
        goToLinkEnter(
          router,
          hasSession: ref.read(authRepositoryProvider).hasSession,
        );
        return;
      }
      router.go(route);
    } catch (e) {
      // 라우터가 없는 환경(테스트 등)에서는 화면을 그대로 둔다
      debugPrint('시작 화면 이동 실패: $e');
    }
  }

  @override
  void dispose() {
    _advance?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: _SplashCanvas());
}

/// Figma `스플래시`(1022:4415) — **단색 배경 위에 로고 하나뿐이다.**
///
/// 병아리도 `오늘의 하루,`도 없다. 그 그림은 로그인 화면(`238:1808`·`1022:4333`)
/// 것이고, 시작 화면은 1.7초 뒤 사라지므로 읽을 것을 얹지 않는다 (이슈 #338).
///
/// **등장 연출을 걸지 않는다.** 머무는 시간이 짧아 페이드를 넣으면 로고가 다 뜨기도
/// 전에 화면이 넘어간다.
class _SplashCanvas extends StatelessWidget {
  const _SplashCanvas();

  /// 로고 자리 — 시안 실측 (115, 396) 164×60.
  static const _logoLeft = 115.0;
  static const _logoTop = 396.0;
  static const _logoWidth = 164.0;

  /// 로고를 읽어 주는 이름.
  ///
  /// 이 화면에는 **글자가 하나도 없다.** 이름을 안 주면 화면 낭독기에 아무것도
  /// 읽히지 않아 "빈 화면"으로 들린다. 실기기 E2E 도 이 이름으로 이 화면이
  /// 떴는지 안다 — 없으면 앱이 뜨기 전에 셔터가 내려가 홈 화면이 찍힌다 (#338).
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colors.splashPlain,
      child: Stack(
        children: [
          Positioned(
            left: _logoLeft.w,
            top: _logoTop.h,
            child: SvgPicture.asset(
              AppAssets.logo,
              width: _logoWidth.w,
              semanticsLabel: context.l10n.onboardingSplashLogoLabel,
            ),
          ),
        ],
      ),
    );
  }
}
