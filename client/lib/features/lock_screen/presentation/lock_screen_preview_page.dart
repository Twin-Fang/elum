import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_toast.dart';
import '../application/lock_screen_providers.dart';
import 'lock_screen_page.dart';

/// 잠금화면 미리 보기: 이 기기 카드 종류로 견본 요약을 잠금화면과 같은 모습으로 (버튼은 안내만)
/// 보호자 견본: 3개 중 2개 끝, 다음 양치하기 · 이룸이 견본: 양치 카드 한 장 (번들 예시 그림)
class LockScreenPreviewPage extends ConsumerWidget {
  const LockScreenPreviewPage({super.key});

  // 견본 일과 수 (3개 중 2개 끝)
  static const _sampleDoneCount = 2;
  static const _sampleTotalCount = 3;
  // 견본 카드 그림 (번들 예시 이미지 id)
  static const _sampleExampleImageId = 'brush_teeth';
  static const _sampleRoutineId = 'lock-screen-preview';

  static LockScreenSnapshot sampleSnapshot(
    BuildContext context,
    LockScreenMode mode,
    DateTime now,
  ) => LockScreenSnapshot(
    mode: mode,
    dateKey: LockScreenSnapshot.dateKeyOf(now),
    doneCount: _sampleDoneCount,
    totalCount: _sampleTotalCount,
    nextRoutineTitle: context.l10n.lockScreenPreviewSampleRoutine,
    elumiCard: mode == LockScreenMode.elumi
        ? LockScreenElumiCard(
            routineId: _sampleRoutineId,
            cardId: _sampleRoutineId,
            routineTitle: context.l10n.lockScreenPreviewSampleRoutine,
            cardText: context.l10n.lockScreenPreviewSampleCard,
            contentLanguage: context.appLocale.languageCode,
            exampleImageId: _sampleExampleImageId,
          )
        : null,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(lockScreenDeviceModeProvider);
    final now = DateTime.now();
    void showPreviewNotice() =>
        showElumToast(context, context.l10n.lockScreenPreviewNotice);
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: LockScreenCardView(
          mode: mode,
          snapshot: sampleSnapshot(context, mode, now),
          now: now,
          onOpenApp: showPreviewNotice,
          onStartRoutine: (_) => showPreviewNotice(),
          onPauseOneHour: showPreviewNotice,
          onClose: context.popOrHome,
        ),
      ),
    );
  }
}

/// 미리 보기 열기 (소개 시트 · 설정 공통)
void openLockScreenPreview(BuildContext context) =>
    unawaited(context.push(Routes.lockScreenPreview));
