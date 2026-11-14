import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../credit/application/credit_start_gate.dart';
import '../../credit/application/credit_top_up_entry.dart';
import '../../credit/domain/credit_summary.dart';
import '../application/routine_notifier.dart';
import 'widgets/create_routine_button.dart';

/// `새로운 일과 만들기` + 시작 전 크레딧 확인.
///
/// 확인을 기다리는 동안 한 번 더 누르면 입력 화면이 두 번 쌓였다. 확인 중에는
/// 누름을 무시한다. 확인은 [creditStartCheckTimeout] 안에 끝나 오래 막히지 않는다.
class StartRoutineButton extends ConsumerStatefulWidget {
  const StartRoutineButton({super.key});

  @override
  ConsumerState<StartRoutineButton> createState() =>
      _StartRoutineButtonState();
}

class _StartRoutineButtonState extends ConsumerState<StartRoutineButton>
    with BusyStateMixin<StartRoutineButton> {
  @override
  Widget build(BuildContext context) =>
      CreateRoutineButton(onTap: _startRoutine, loading: busy);

  /// 일과 만들기 시작. 이전 입력이 남아 있으면 안 되므로 항상 초기화한다.
  ///
  /// 이번 주 크레딧을 다 썼으면 들어가지 않고 알린다 — 입력·질문·보상까지
  /// 다 적은 뒤 마지막에 막히면 적은 것이 헛수고가 된다.
  Future<void> _startRoutine() async {
    // 확인하는 동안만 잠근다. 결과가 null 일 수 있어 기록으로 감싸 건너뛴 경우와 가른다.
    final check = await runBusy(
      () async => (blocked: await creditBlocksRoutineStart(ref)),
    );
    if (check == null || !mounted) return;
    await continueRoutineStart(context, ref, check.blocked);
  }
}

/// 크레딧 확인을 마친 뒤 일과 만들기로 들어간다 (홈 · 일과관리 `+ 일과 만들기` 공통)
///
/// 막혔으면 안내만 띄우고 제자리에 남는다. 아니면 흐름 초기화 > 입력 화면.
Future<void> continueRoutineStart(
  BuildContext context,
  WidgetRef ref,
  CreditSummary? blocked,
) async {
  if (blocked != null) {
    // 크레딧 더 받기 시트. 들어가지 않고 제자리에 남음 (광고로 받으면 `이어서 만들기` 로 다시 확인 후 시작)
    await showCreditBlockedNotice(
      context,
      ref,
      blocked,
      retry: (
        label: context.l10n.creditTopUpRoutineContinue,
        run: () async {
          final blockedAgain = await creditBlocksRoutineStart(ref);
          if (!context.mounted) return;
          await continueRoutineStart(context, ref, blockedAgain);
        },
      ),
    );
    return;
  }
  ref.read(routineFlowProvider.notifier).reset();
  // push 가 끝나기를 기다리지 않는다 — 흐름이 `go` 로 홈에 돌아오면 그 Future 가
  // 끝나지 않을 수 있고, 그러면 버튼이 영영 눌리지 않는다.
  context.push(Routes.routineInput);
}
