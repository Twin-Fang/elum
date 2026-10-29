import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../ads/application/tracking_prompt_gate.dart';

/// 코치마크를 띄워도 되는 때 판단: 화면 맨 앞, 전환 끝, 추적 허용 팝업 끝 > [onCoachMarkStartReady]
///
/// 가려져 있으면(공지 팝업·시트) 0.5초마다 최대 30초 다시 본다. 팝업이 닫혀도 화면이 다시
/// 그려지지 않아서, 기다렸다 묻지 않으면 그 실행에서 영영 시작하지 못한다.
mixin CoachMarkStartGate<T extends StatefulWidget> on State<T> {
  static const _retryEvery = Duration(milliseconds: 500);
  static const _maxRetries = 60;

  Timer? _coachRetry;
  int _coachRetryCount = 0;
  Timer? _coachSettle;
  bool _isWaitingRoute = false;

  /// 추적 허용 팝업이 끝났는가. 팝업과 겹치면 막이 팝업에 가려진다
  bool _isTrackingPromptDone = false;
  bool _isWaitingTrackingPrompt = false;

  /// 맨 앞이 된 뒤 이만큼 그대로여야 시작한다. null 이면 바로 시작
  Duration? get coachMarkSettleDuration => null;

  /// 띄워도 되는 때가 됐다. 켤지(본 기록 등)는 여기서 정한다
  void onCoachMarkStartReady();

  /// 띄울 때인지 본다. 조건이 아직이면 기다렸다 스스로 다시 부른다
  void checkCoachMarkStart() {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _coachSettle?.cancel();
      _coachSettle = null;
      _retryCoachMarkStartLater();
      return;
    }
    // 전환 도중에 띄우면 대상이 움직이는 중이라 구멍이 어긋난다
    final animation = route?.animation;
    if (animation != null && animation.status != AnimationStatus.completed) {
      if (_isWaitingRoute) return;
      _isWaitingRoute = true;
      void onStatus(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatus);
        _isWaitingRoute = false;
        checkCoachMarkStart();
      }

      animation.addStatusListener(onStatus);
      return;
    }
    if (!_isTrackingPromptDone) {
      if (_isWaitingTrackingPrompt) return;
      _isWaitingTrackingPrompt = true;
      waitForTrackingPrompt().whenComplete(() {
        _isTrackingPromptDone = true;
        _isWaitingTrackingPrompt = false;
        // 기다리는 사이 화면이 바뀌었을 수 있어 처음부터 다시 따진다
        checkCoachMarkStart();
      });
      return;
    }
    final settle = coachMarkSettleDuration;
    if (settle == null) {
      onCoachMarkStartReady();
      return;
    }
    // 바로 켜지 않고 잠시 지켜본다 — 그 사이 다시 가려지면 위에서 타이머가 취소된다
    if (_coachSettle?.isActive ?? false) return;
    _coachSettle = Timer(settle, _startAfterSettle);
  }

  void _startAfterSettle() {
    _coachSettle = null;
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _retryCoachMarkStartLater();
      return;
    }
    onCoachMarkStartReady();
  }

  void _retryCoachMarkStartLater() {
    if (_coachRetry?.isActive ?? false) return;
    if (_coachRetryCount++ >= _maxRetries) return;
    _coachRetry = Timer(_retryEvery, checkCoachMarkStart);
  }

  @override
  void dispose() {
    _coachRetry?.cancel();
    _coachSettle?.cancel();
    super.dispose();
  }
}
