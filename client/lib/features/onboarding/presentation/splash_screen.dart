import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../auth/domain/app_role.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../auth/data/auth_repository.dart';
import '../application/onboarding_notifier.dart';

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
}) =>
    hasSession && (onboardingCompleted || isElumiDevice);

/// 세션이 있는 사람을 어디로 보낼지 (이슈 #212).
///
/// 역할([selectedRole])과 연결 여부([isElumiDevice])는 **다른 값**이다.
/// 역할은 고른 순간, 연결은 성공한 순간 정해진다. 역할만 고르고 연결하지 않은
/// 채로 앱을 닫는 사람이 있으므로 둘을 따로 본다.
@visibleForTesting
String resolveDestination({
  required bool hasSession,
  required bool onboardingCompleted,
  required bool isElumiDevice,
  required String? selectedRole,
}) {
  if (!hasSession) {
    // 이룸이 휴대폰은 로그인할 계정이 없다 — 연결 화면으로 보낸다 (이슈 #206)
    return isElumiDevice ? Routes.linkEnter : Routes.login;
  }
  if (isElumiDevice) return Routes.child;

  final role = AppRole.fromStorage(selectedRole);
  return switch (role) {
    // 역할이 없는데 온보딩을 마쳤다면 **역할이 생기기 전에 가입한 보호자**다.
    // 이미 답한 것을 다시 묻지 않는다 (이슈 #212 — 기존 사용자 마이그레이션).
    null => onboardingCompleted ? Routes.guardian : Routes.roleSelect,
    // 이룸이라고는 했는데 아직 연결 전이다
    AppRole.elumi => Routes.linkEnter,
    AppRole.guardian =>
      onboardingCompleted ? Routes.guardian : Routes.onboardingName,
  };
}

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

  String _destination() {
    final storage = ref.read(localStorageProvider);
    return resolveDestination(
      hasSession: ref.read(authRepositoryProvider).hasSession,
      onboardingCompleted: storage.isOnboardingCompleted,
      isElumiDevice: storage.isElumiDevice,
      selectedRole: storage.selectedRole,
    );
  }

  /// context.go()만으로는 DevToolsOverlay 레이어에서 라우터를 찾지 못한다.
  void _goTo(String route) {
    try {
      final router = GoRouter.of(context);
      // 연결 암호 넣기는 **뒤로 갈 수 있어야 한다** (이슈 #212). go로 바로 띄우면
      // 스택이 비어 pop이 실패하므로, 역할 선택을 깔고 그 위에 얹는다.
      if (route == Routes.linkEnter) {
        router.go(Routes.roleSelect);
        router.push(Routes.linkEnter);
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
  static const _logoLabel = '이룸';

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
              semanticsLabel: _logoLabel,
            ),
          ),
        ],
      ),
    );
  }
}
