import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_secondary_button.dart';
import '../../application/lock_screen_providers.dart';
import 'lock_screen_interval_picker.dart';

/// 켜진 상태: 상태 한 줄(켜짐 · HH:mm까지 쉬는 중) > 간격 바꾸기 > 미리 보기 · 끄기
class LockScreenEnabledPanel extends ConsumerWidget {
  const LockScreenEnabledPanel({super.key, required this.settings});

  final LockScreenSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final pausedUntil = settings.pausedUntil;
    final notifier = ref.read(lockScreenStateProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          pausedUntil == null
              ? context.l10n.lockScreenEnabledStatus
              : context.l10n.lockScreenPausedUntil(
                  TimeOfDay.fromDateTime(pausedUntil).format(context),
                ),
          style: context.typo.creditTitle.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: space.lg.h),
        LockScreenIntervalPicker(
          selectedIntervalMinutes: settings.intervalMinutes,
          onSelected: (intervalMinutes) =>
              unawaited(notifier.updateInterval(intervalMinutes)),
        ),
        SizedBox(height: space.lg.h),
        ElumSecondaryButton(
          label: context.l10n.lockScreenPreviewAction,
          onTap: () => context.push(Routes.lockScreenPreview),
        ),
        SizedBox(height: space.xs.h),
        ElumSecondaryButton(
          label: context.l10n.lockScreenTurnOff,
          onTap: () => unawaited(notifier.disable()),
        ),
      ],
    );
  }
}
