import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../data/notification_permission_gate.dart';
import 'push_permission_prompt.dart';

final deviceNotificationPermissionControllerProvider = NotifierProvider.autoDispose<
    DeviceNotificationPermissionController, bool>(
  DeviceNotificationPermissionController.new,
);

/// 알림 설정 화면의 기기 알림 꺼짐 여부: 확인, 켜기(권한 창 또는 기기 설정)
/// 상태값 true = 꺼짐. 확인 전·확인 실패는 false (안내 띠·설정 잠금 없음)
class DeviceNotificationPermissionController extends Notifier<bool> {
  NotificationPermissionGate get _gate =>
      ref.read(notificationPermissionGateProvider);

  @override
  bool build() {
    recheck();
    return false;
  }

  /// 진입·앱 복귀 시 권한 다시 확인
  Future<void> recheck() async {
    try {
      final isGranted = await _gate.isGranted();
      if (ref.mounted) state = !isGranted;
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': 'checkPermission'});
    }
  }

  /// 켜기: 한 번도 안 물은 기기면 시스템 권한 창, 이미 거부했으면 기기 설정
  Future<void> turnOn() async {
    try {
      final isRequested =
          await ref.read(pushPermissionPromptProvider).requestIfNeverAsked();
      if (isRequested) {
        await recheck();
        return;
      }
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': 'requestPermission'});
    }
    try {
      await _gate.openDeviceSettings();
    } catch (e, st) {
      AppLogger.error('notification', e, st, {'step': 'openDeviceSettings'});
    }
  }
}
