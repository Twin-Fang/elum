import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/assets/app_assets.dart';
import '../core/l10n/l10n_context.dart';
import '../core/widgets/home_notice_card.dart';
import '../features/notification/application/device_notification_permission_controller.dart';
import '../features/notification/application/home_notification_notice_provider.dart';

/// 보호자 홈 알림 꺼짐 카드 (#1275): 왜 켜는지 + 받는 알림 알약 2개 + 알림 켜기
/// 보일지는 [homeNoticeChoiceProvider] 가 정함. 켜기: 안 물었으면 OS 권한 요청, 이미 거부했으면 OS 앱 설정 (`turnOn`)
/// 닫기: 7일 숨김
class NotificationOffNoticeCard extends ConsumerWidget {
  const NotificationOffNoticeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return HomeNoticeCard(
      title: l10n.notificationOffNoticeTitle,
      body: l10n.notificationOffNoticeBody,
      highlights: [l10n.notificationOffNoticeHighlightRoutineDone, l10n.notificationOffNoticeHighlightCaregiver],
      actionLabel: l10n.notificationOffNoticeAction,
      tileAsset: AppAssets.homeNoticeBell,
      onAction: ref.read(deviceNotificationPermissionControllerProvider.notifier).turnOn,
      onDismiss: ref.read(homeNotificationNoticeDismissalProvider.notifier).dismiss,
      dismissLabel: l10n.commonClose,
    );
  }
}
