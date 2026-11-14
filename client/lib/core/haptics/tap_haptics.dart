import 'dart:async';

import 'package:flutter/services.dart';

/// 보호자 화면 누름 햅틱 (가벼운 선택 한 번): 안내 창·시트 버튼 · 홈 안내 카드
void playTapHaptic() => unawaited(HapticFeedback.selectionClick());

/// 누름 동작에 햅틱을 붙임 (null 이면 꺼진 버튼 그대로 null)
VoidCallback? withTapHaptic(VoidCallback? onTap) {
  if (onTap == null) return null;
  return () {
    playTapHaptic();
    onTap();
  };
}

/// 보상 축하 햅틱 (중간 세기 한 번): AppCelebration 등장 순간
void playCelebrationHaptic() => unawaited(HapticFeedback.mediumImpact());
