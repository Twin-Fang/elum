import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/elum_guide_panel.dart';
import '../presentation/lock_screen_intro_sheet.dart';
import '../presentation/lock_screen_preview_page.dart';
import 'lock_screen_providers.dart';

/// 이 실행에서 소개 판단을 이미 했나 (홈이 다시 그려질 때마다 채널을 부르지 않게)
bool _hasCheckedIntroThisRun = false;

/// 보호자 홈 > 잠금화면 소개 시트 (조건이 맞을 때만): 판정 > 노출 기록 > 시트 > 켜러 가기 · 미리 보기
/// 다른 기능이 lock_screen 의 presentation 을 직접 알지 않게 하는 입구
Future<void> maybeShowLockScreenIntro(
  BuildContext context,
  WidgetRef ref, {
  required bool hasElumiCompletedRoutine,
}) async {
  if (_hasCheckedIntroThisRun || !hasElumiCompletedRoutine) return;
  _hasCheckedIntroThisRun = true;
  final shouldShow = await shouldShowLockScreenIntro(
    ref,
    hasElumiCompletedRoutine: hasElumiCompletedRoutine,
  );
  if (!shouldShow || !context.mounted) return;
  recordLockScreenIntroShown(ref);
  final choice = await showElumGuideSheet<LockScreenIntroChoice>(
    context: context,
    builder: (_) => const LockScreenIntroSheet(),
  );
  if (!context.mounted) return;
  switch (choice) {
    case LockScreenIntroChoice.turnOn:
      await context.push(Routes.lockScreenSettings);
    case LockScreenIntroChoice.preview:
      openLockScreenPreview(context);
    case null:
      break;
  }
}
