import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n_context.dart';
import '../core/widgets/notification_off_notice.dart';
import '../features/notification/application/device_notification_permission_controller.dart';

/// 보호자 홈의 알림 꺼짐 카드를 권한 상태에 묶는 곳: 기기 알림이 꺼졌을 때만 보임
///
/// 앱이 다시 앞으로 오면 권한을 다시 읽어 켜졌으면 바로 사라짐. 권한을 못 읽으면 아무것도 안 보임.
/// 켜기: 안 물었으면 OS 권한 요청, 이미 거부했으면 OS 앱 설정 (`turnOn`)
class NotificationOffNoticeHost extends ConsumerStatefulWidget {
  const NotificationOffNoticeHost({super.key, required this.onDismiss});

  /// 닫기(x) 누름
  final VoidCallback onDismiss;

  @override
  ConsumerState<NotificationOffNoticeHost> createState() => _NotificationOffNoticeHostState();
}

class _NotificationOffNoticeHostState extends ConsumerState<NotificationOffNoticeHost> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(deviceNotificationPermissionControllerProvider.notifier).recheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(deviceNotificationPermissionControllerProvider)) return const SizedBox.shrink();
    final l10n = context.l10n;
    return NotificationOffNotice(
      title: l10n.notificationOffNoticeTitle,
      body: l10n.notificationOffNoticeBody,
      turnOnLabel: l10n.notificationTurnOnDeviceNotification,
      onTurnOn: ref.read(deviceNotificationPermissionControllerProvider.notifier).turnOn,
      onDismiss: widget.onDismiss,
      dismissLabel: l10n.commonClose,
    );
  }
}
