import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n_context.dart';
import '../core/widgets/settings_tile.dart';
import '../features/lock_screen/application/lock_screen_providers.dart';

/// 설정의 `잠금화면 카드` 줄 (Android 만, 그 밖은 자리 없음): 오른쪽 값 켜짐 · 꺼짐 · 권한 필요
/// 누르면 [onOpen] (보호자 설정은 바로, 이룸이 설정은 보호자 암호 확인 뒤). 돌아오면 값을 다시 읽음
class LockScreenSettingsTile extends ConsumerWidget {
  const LockScreenSettingsTile({
    super.key,
    required this.onOpen,
    this.isEnabled = true,
  });

  final Future<void> Function() onOpen;

  /// false 면 누를 수 없음 (설정이 다른 작업 중)
  final bool isEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isLockScreenAvailableProvider)) {
      return const SizedBox.shrink();
    }
    final lockScreenState = ref.watch(lockScreenStateProvider).value;
    final valueText = lockScreenState == null
        ? null
        : lockScreenState.isPermissionMissing
        ? context.l10n.lockScreenPermissionMissingValue
        : lockScreenState.settings.isEnabled
        ? context.l10n.lockScreenOnValue
        : context.l10n.notificationOffValue;
    return SettingsTile(
      label: context.l10n.lockScreenSettingsTitle,
      valueText: valueText,
      showChevronWithValue: true,
      onTap: isEnabled
          ? () async {
              await onOpen();
              // 설정 화면에서 켜기·끄기를 했을 수 있음
              await ref.read(lockScreenStateProvider.notifier).refresh();
            }
          : null,
    );
  }
}
