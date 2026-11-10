import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/batchim.dart';
import '../core/l10n/l10n_context.dart';
import '../core/widgets/notification_off_notice.dart';
import '../features/guardian/application/guardian_child_identity.dart';
import '../features/notification/application/device_notification_permission_controller.dart';

/// 알림 꺼짐 안내를 권한 상태에 묶는 곳 (보호자 홈 한 줄 · 알림 화면 카드): 기기 알림이 꺼졌을 때만 보임
///
/// 앱이 다시 앞으로 오면 권한을 다시 읽어 켜졌으면 바로 사라짐. 권한을 못 읽으면 아무것도 안 보임.
/// 켜기: 안 물었으면 OS 권한 요청, 이미 거부했으면 OS 앱 설정 (`turnOn`)
class NotificationOffNoticeHost extends ConsumerStatefulWidget {
  const NotificationOffNoticeHost({super.key, required this.style, this.onDismiss});

  final NotificationOffNoticeStyle style;

  /// 닫기(x) 누름 (null 이면 닫기 없음)
  final VoidCallback? onDismiss;

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
    final isCard = widget.style == NotificationOffNoticeStyle.card;
    final savedName = ref.watch(guardianChildIdentityProvider.select((identity) => identity.name));
    final name = savedName.isEmpty ? l10n.commonElumiName : savedName;
    return NotificationOffNotice(
      style: widget.style,
      title: l10n.notificationOffNoticeTitle,
      body: isCard ? l10n.notificationOffNoticeBody(name, batchimOf(name)) : null,
      turnOnLabel: isCard ? l10n.notificationOffNoticeTurnOn : l10n.notificationTurnOnDeviceNotification,
      onTurnOn: ref.read(deviceNotificationPermissionControllerProvider.notifier).turnOn,
      onDismiss: widget.onDismiss,
      dismissLabel: l10n.commonClose,
    );
  }
}
