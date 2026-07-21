import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_motion.dart';

/// go_router 페이지 전환 헬퍼 — motion.md "전환 없는 즉시 교체 금지" 구현.
///
/// 전환은 **목적지 라우트**의 pageBuilder가 결정한다. pop은 같은 전환을
/// 역재생하므로 뒤로가기는 자동으로 진입의 역방향이 된다.

/// 페이지 전환 시간. 테스트가 토큰 사용을 고정한다.
const kPageTransitionDuration = AppMotion.slow;

/// 수평 슬라이드 + fade. 온보딩 단계 진행처럼 "다음으로 나아가는" 전환.
CustomTransitionPage<void> slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: kPageTransitionDuration,
    reverseTransitionDuration: kPageTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // 화면 폭의 25% 지점에서 미끄러져 들어온다 — 전폭 슬라이드보다 차분하고
      // fade와 겹치면 이동 거리가 짧아도 방향성이 충분히 읽힌다.
      final slide = Tween<Offset>(
        begin: const Offset(0.25, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: AppMotion.decelerate)).animate(animation);

      return FadeTransition(
        opacity: CurveTween(curve: AppMotion.entry).animate(animation),
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

/// fade 전환. 온보딩 완료 → 보호자 홈처럼 맥락이 바뀌는 진입.
CustomTransitionPage<void> fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: kPageTransitionDuration,
    reverseTransitionDuration: kPageTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: AppMotion.standard).animate(animation),
        child: child,
      );
    },
  );
}
