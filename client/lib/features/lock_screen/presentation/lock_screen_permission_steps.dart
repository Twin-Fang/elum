import 'package:flutter/widgets.dart';

import '../../../core/l10n/l10n_context.dart';
import '../application/lock_screen_providers.dart';

/// 잠금화면 권한 단계 4개: 다른 앱 위에 표시 · 알림 · 배터리 최적화 제외 (필수) · 삼성 절전 예외 (권장, 삼성만)
enum LockScreenPermissionStep {
  overlay(isRequired: true),
  notification(isRequired: true),
  battery(isRequired: true),
  samsungPower(isRequired: false);

  const LockScreenPermissionStep({required this.isRequired});

  final bool isRequired;

  String title(BuildContext context) => switch (this) {
    overlay => context.l10n.lockScreenPermissionOverlayTitle,
    notification => context.l10n.lockScreenPermissionNotificationTitle,
    battery => context.l10n.lockScreenPermissionBatteryTitle,
    samsungPower => context.l10n.lockScreenPermissionSamsungTitle,
  };

  String reason(BuildContext context) => switch (this) {
    overlay => context.l10n.lockScreenPermissionOverlayReason,
    notification => context.l10n.lockScreenPermissionNotificationReason,
    battery => context.l10n.lockScreenPermissionBatteryReason,
    samsungPower => context.l10n.lockScreenPermissionSamsungReason,
  };

  /// 이 기기에서 밟을 단계 (삼성 절전 예외는 삼성 기기만)
  static List<LockScreenPermissionStep> stepsFor(
    LockScreenPermissionStatus status,
  ) => [overlay, notification, battery, if (status.isSamsung) samsungPower];

  /// 단계가 끝났나 (삼성 절전 예외는 읽을 방법이 없어 사용자 확인으로만)
  bool isDoneIn(
    LockScreenPermissionStatus status, {
    required bool isSamsungStepFinished,
  }) => switch (this) {
    overlay => status.canDrawOverlays,
    notification => status.hasNotificationPermission,
    battery => status.isIgnoringBatteryOptimizations,
    samsungPower => isSamsungStepFinished,
  };

  /// 이 단계의 설정 화면 열기
  Future<void> openSettings(LockScreenBridge bridge) => switch (this) {
    overlay => bridge.openOverlaySettings(),
    notification => bridge.openNotificationSettings(),
    battery => bridge.openBatteryOptimizationSettings(),
    samsungPower => bridge.openSamsungPowerSettings(),
  };
}
