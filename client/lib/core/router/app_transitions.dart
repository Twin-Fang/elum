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

/// 일과 만들기 흐름 안의 전환 — **배경은 두고 글자만 넘어간다** (#380).
///
/// 흐름은 배경 하나(`RoutineFlowBackdrop`)를 함께 쓰고 화면은 바탕이 투명하다.
/// 그래서 [slidePage]처럼 들어오는 화면이 나가는 화면을 덮을 수 없다 — 둘 다
/// 비치므로 그대로 겹치면 제목 두 개가 포개진다.
///
/// 나가는 화면이 **먼저 흐려져 비키고**(앞 30%), 들어오는 화면이 그 뒤를 이어
/// 떠오른다(나머지 70%). 둘이 동시에 반쯤 보이는 순간이 없다. 이동은 폭의 8%
/// (393 기준 약 31)만 — 방향만 읽히면 된다. 크게 움직이면 배경은 가만히 있는데
/// 글자만 멀리 날아가 둘이 따로 논다.
///
/// 돌아갈 때는 같은 순서를 거꾸로 밟는다 — 되돌아가는 화면이 먼저 비키고,
/// 아래 화면이 떠오른다. `reverseCurve`가 없으면 아래 화면이 마지막 30%에서야
/// 급히 나타난다.
///
/// 동작 줄이기면 미끄러지지 않고 흐려지기만 한다 (iOS 동작 줄이기와 같은 방식).
CustomTransitionPage<void> flowPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: kPageTransitionDuration,
    reverseTransitionDuration: kPageTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);

      // 들어오는 화면 — 앞 화면이 비킨 뒤(30%부터) 떠오른다.
      final enter = CurvedAnimation(
        parent: animation,
        curve: const Interval(_handoff, 1, curve: AppMotion.decelerate),
        // 돌아갈 때는 이 화면이 먼저(뒤로 가는 시간의 앞 30%) 비킨다.
        reverseCurve: const Interval(1 - _handoff, 1, curve: AppMotion.standard),
      );

      // 나가는 화면 — 앞 30% 안에 비킨다.
      final leave = CurvedAnimation(
        parent: secondaryAnimation,
        curve: const Interval(0, _handoff, curve: AppMotion.standard),
        // 돌아올 때는 위 화면이 비킨 뒤(나머지 70%) 떠오른다.
        //
        // **거꾸로 흐를 때는 곡선을 뒤집어 준다(`flipped`).** 되돌아갈 때 값은
        // 1→0으로 줄어드는데 곡선은 그 값에 그대로 걸린다. 감속 곡선을 그대로
        // 두면 시간으로는 가속이 되어, 아래 화면이 끝에서 급히 튀어나온다.
        // (나가는 쪽 easeInOut 은 좌우 대칭이라 뒤집어도 같다.)
        reverseCurve: Interval(
          0,
          1 - _handoff,
          curve: AppMotion.decelerate.flipped,
        ),
      );

      Widget content = FadeTransition(opacity: enter, child: child);
      content = FadeTransition(
        opacity: ReverseAnimation(leave),
        child: content,
      );
      if (reduceMotion) return content;

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(_shift, 0),
          end: Offset.zero,
        ).animate(enter),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-_shift, 0),
          ).animate(leave),
          child: content,
        ),
      );
    },
  );
}

/// 나가는 화면이 비키는 몫 — 전환 시간의 30%(120ms).
///
/// Material 의 fade through 와 같은 비율이다. 더 짧으면 앞 화면이 번쩍 사라지고,
/// 더 길면 빈 배경만 보이는 틈이 생긴다.
const _handoff = 0.3;

/// 글자가 옆으로 움직이는 거리 — 화면 폭의 8%.
const _shift = 0.08;
