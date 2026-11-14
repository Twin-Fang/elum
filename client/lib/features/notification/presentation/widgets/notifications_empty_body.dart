import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/elum_empty_state.dart';

/// 알림이 하나도 없을 때: 알림 없음 3D 그림 + 문구 + 어떤 알림이 오는지 한 줄 + 알림 설정 (로딩·실패와 다른 화면)
class NotificationsEmptyBody extends StatelessWidget {
  const NotificationsEmptyBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ElumEmptyState(
      illustrationAsset: AppAssets.emptyStateNoNotifications,
      title: l10n.notificationEmpty,
      body: l10n.notificationEmptyBody,
      actionLabel: l10n.notificationEmptyOpenSettings,
      onAction: () => context.push(Routes.guardianNotificationSettings),
    );
  }
}
