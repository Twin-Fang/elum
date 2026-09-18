import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/splash_scene.dart';
import '../../auth/data/auth_repository.dart';
import '../application/onboarding_notifier.dart';

/// Figma `시작` (238:1808) — 서비스 진입 화면.
///
/// 그림은 [SplashScene]이 그린다. 로그인 화면이 같은 그림을 쓰기 때문에
/// 한 벌로 묶어 뒀다 (이슈 #207). 이 화면은 **언제 어디로 넘길지**만 맡는다.
///
/// 시작 화면을 건너뛸지 판단한다.
///
/// 이미 로그인했고 온보딩도 끝났다면 갈 곳이 하나로 정해져 있다. 그런데도 버튼을
/// 한 번 더 누르게 하면, 매일 여는 사용자에게 의미 없는 탭이 계속 쌓인다.
@visibleForTesting
bool shouldSkipSplash({
  required bool hasSession,
  required bool onboardingCompleted,
}) =>
    hasSession && onboardingCompleted;

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
      final skip = shouldSkipSplash(
        hasSession: ref.read(authRepositoryProvider).hasSession,
        onboardingCompleted: ref.read(localStorageProvider).isOnboardingCompleted,
      );
      if (skip) {
        _goTo(Routes.guardian);
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

  String _destination() => !ref.read(authRepositoryProvider).hasSession
      ? Routes.login
      : ref.read(localStorageProvider).isOnboardingCompleted
          ? Routes.guardian
          : Routes.onboardingName;

  /// context.go()만으로는 DevToolsOverlay 레이어에서 라우터를 찾지 못한다.
  void _goTo(String route) {
    try {
      GoRouter.of(context).go(route);
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
  Widget build(BuildContext context) => const Scaffold(body: SplashScene());
}
