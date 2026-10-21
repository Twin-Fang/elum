import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_switch_tile.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../application/notification_settings_controller.dart';
import '../../domain/notification_settings.dart';

/// 알림 설정 스위치 묶음 2개: 모든 알림 받기 카드 + 종류별 7개 카드 (시안 1732:8563)
class NotificationSettingRows extends ConsumerWidget {
  const NotificationSettingRows({
    super.key,
    required this.settings,
    this.isShownAllOff = false,
  });

  final NotificationSettings settings;

  /// 저장값과 무관하게 전부 꺼진 모양으로 그림 (기기 알림 꺼짐)
  final bool isShownAllOff;

  /// 두 카드 사이 간격
  static const _groupGap = 16.0;

  /// 스위치 하나 > 저장, 실패하면 팝업 (값은 컨트롤러가 되돌림)
  Future<void> _onSettingToggled(
    BuildContext context,
    WidgetRef ref,
    NotificationSettingField field,
    bool isOn,
  ) async {
    final error = await ref
        .read(notificationSettingsControllerProvider.notifier)
        .toggle(field, isOn);
    if (error == null || !context.mounted) return;
    await showFailure(
      context,
      error,
      fallback: context.l10n.notificationSettingSaveFailed,
      fallbackCode: 'E-NOTIF-SETTING',
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    WidgetRef ref,
    NotificationSettingField field,
  ) =>
      SettingsSwitchTile(
        isInCard: true,
        label: _labelOf(context.l10n, field),
        value: !isShownAllOff && settings.valueOf(field),
        onChanged: (isOn) => _onSettingToggled(context, ref, field, isOn),
      );

  /// 스위치 > 줄 이름
  static String _labelOf(AppLocalizations l10n, NotificationSettingField field) =>
      switch (field) {
        NotificationSettingField.all => l10n.notificationSettingAll,
        NotificationSettingField.routineCompleted => l10n.notificationSettingRoutineCompleted,
        NotificationSettingField.routineSent => l10n.notificationSettingRoutineSent,
        NotificationSettingField.coGuardianJoined => l10n.notificationSettingCoGuardianJoined,
        NotificationSettingField.creditRefilled => l10n.notificationSettingCreditRefilled,
        NotificationSettingField.feedbackResolved => l10n.notificationSettingFeedbackResolved,
        NotificationSettingField.talkCommented => l10n.notificationSettingTalkCommented,
        NotificationSettingField.talkImported => l10n.notificationSettingTalkImported,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          hasDividers: false,
          children: [_buildSwitchTile(context, ref, NotificationSettingField.all)],
        ),
        SizedBox(height: _groupGap.h),
        SettingsGroup(
          hasDividers: false,
          children: [
            for (final type in NotificationSettingField.types)
              _buildSwitchTile(context, ref, type),
          ],
        ),
      ],
    );
  }
}
