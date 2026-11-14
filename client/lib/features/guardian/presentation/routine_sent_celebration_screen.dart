import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/app_celebration.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../link/application/linked_device_check.dart';
import '../../notification/application/push_permission_prompt.dart';
import 'memory/routine_memory_observation_sheet.dart';

/// 첫 일과 보내기 축하: 그림 튐 > 빛 > `이룸이 기기로 보냈어요` > 한 줄 > 다음 행동 + `홈으로`
/// 다음 행동 2가지: 기기 없음 > 기기 연결하기 · 붙어 있음 > 이룸이 화면 미리 보기 (모르면 홈으로만)
/// 축하는 화면 안에서만 (연결 상태 조회가 실패해도 축하는 그대로)
class RoutineSentCelebrationScreen extends ConsumerWidget {
  const RoutineSentCelebrationScreen({super.key, this.routineId});

  /// 보낸 일과 id (홈으로 갈 때 AI 메모 확인용, 일과관리에서 보냈으면 null)
  final String? routineId;

  /// 홈으로: 미뤄 둔 알림 권한 안내 · AI 메모 확인을 홈 위에서 (축하 위에 시트가 겹치지 않게)
  void _goHome(BuildContext context, WidgetRef ref) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final pushPermissionPrompt = ref.read(pushPermissionPromptProvider);
    context.go(Routes.guardian);
    // 맨 위 네비게이터는 이 화면보다 오래 살고, 두 함수 모두 mounted 를 다시 확인함
    unawaited(pushPermissionPrompt.maybeAsk(rootContext));
    final sentRoutineId = routineId;
    if (sentRoutineId != null) unawaited(showMemoryObservationsAfterSend(rootContext, sentRoutineId));
  }

  /// 기기 연결: 연결 화면에서 돌아오면 상태를 다시 받아 다음 행동을 바꿈
  Future<void> _linkDevice(BuildContext context, WidgetRef ref) async {
    await context.push(Routes.linkCode);
    ref.refreshLinkedDevice();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isDeviceLinked = ref.watch(hasLinkedDeviceProvider);
    final homeButton = isDeviceLinked == null
        ? ElumButton(label: l10n.commonGoHome, onPressed: () => _goHome(context, ref))
        : null;
    final nextActionButton = switch (isDeviceLinked) {
      null => null,
      false => ElumButton(label: l10n.routineSentLinkDevice, onPressed: () => _linkDevice(context, ref)),
      true => ElumButton(label: l10n.routineSentPreviewElumi, onPressed: () => context.go(Routes.child)),
    };
    return PopScope(
      // 시스템 뒤로가기 = 홈으로 (축하 화면은 go 로 열려 돌아갈 곳이 없을 수 있음)
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome(context, ref);
      },
      child: ElumScaffold(
        bottomButton: nextActionButton ?? homeButton,
        belowButton: nextActionButton == null
            ? null
            : ElumSecondaryButton(label: l10n.commonGoHome, onTap: () => _goHome(context, ref)),
        child: ElumStateBody(
          child: AppCelebration(
            illustrationAsset: AppAssets.celebrationSentToDevice,
            title: l10n.routineSentTitle,
            reasonText: isDeviceLinked == false ? l10n.routineSentReasonNotLinked : l10n.elumiFinishNotifyLine,
          ),
        ),
      ),
    );
  }
}
