import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../assets/app_assets.dart';
import '../l10n/l10n_context.dart';
import '../layout/layout_context_ext.dart';
import '../layout/window_size_class.dart';
import 'elum_guide_panel.dart';
import 'elum_secondary_button.dart';

/// 기기 설정에서 알림 켜는 법 안내 (권한을 거부한 기기, #1275): 설정 열기(true) / 나중에(false) / 닫기(null)
/// 폰은 아래 시트, 태블릿은 가운데 창 (#1455 알림 켜기 안내와 같은 자리)
Future<bool?> showNotificationSettingsGuideSheet(BuildContext context) {
  final isPhone = context.sizeClass == WindowSizeClass.compact;
  final placement = isPhone ? ElumGuidePlacement.sheet : ElumGuidePlacement.dialog;
  Widget panelOf(BuildContext promptContext) => _NotificationSettingsGuidePanel(placement: placement);
  return isPhone
      ? showElumGuideSheet<bool>(context: context, builder: panelOf)
      : showElumGuideDialog<bool>(context: context, builder: panelOf, barrierDismissible: true);
}

/// 그림 > 제목 > 이유 한 줄 > 단계 줄 (iOS 3단계 · Android 2단계) > 설정 열기 · 나중에
class _NotificationSettingsGuidePanel extends StatelessWidget {
  const _NotificationSettingsGuidePanel({required this.placement});

  final ElumGuidePlacement placement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final illustrationSize = placement == ElumGuidePlacement.sheet
        ? ElumGuideIllustrationSize.sheet
        : ElumGuideIllustrationSize.dialog;
    // iOS 는 앱 설정 첫 화면이 열려 「알림」을 한 번 더 눌러야 함, Android 는 앱 알림 화면이 바로 열림
    final isAppNotificationPageOpenedDirectly = defaultTargetPlatform == TargetPlatform.android;
    return ElumGuidePanel(
      placement: placement,
      illustration: ElumGuideIllustration(asset: AppAssets.homeNoticeBell, size: illustrationSize),
      title: l10n.notificationSettingsGuideTitle,
      description: l10n.notificationSettingsGuideBody,
      content: [
        ElumGuideFeatureRow(iconAsset: AppAssets.iconSettings, title: l10n.notificationSettingsGuideStepOpen),
        if (!isAppNotificationPageOpenedDirectly)
          ElumGuideFeatureRow(iconAsset: AppAssets.iconBell, title: l10n.notificationSettingsGuideStepNotifications),
        ElumGuideFeatureRow(iconAsset: AppAssets.iconCheck, title: l10n.notificationSettingsGuideStepAllow),
      ],
      primaryAction: ElumGuideAction(
        label: l10n.notificationSettingsGuideOpen,
        onTap: () => Navigator.of(context).pop(true),
      ),
      secondaryActions: [
        ElumSecondaryButton(label: l10n.pushPermissionLater, onTap: () => Navigator.of(context).pop(false)),
      ],
    );
  }
}
