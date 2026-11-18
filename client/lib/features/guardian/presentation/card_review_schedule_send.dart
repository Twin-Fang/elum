import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../../subscription/domain/plan_benefit.dart';
import '../application/routine_notifier.dart';
import '../application/routine_schedule_controller.dart';
import '../domain/routine_schedule.dart';
import 'widgets/routine_schedule_labels.dart';
import 'widgets/routine_schedule_sheet.dart';

/// 카드 확인 예약 도구: Free 는 Pro 안내 · Pro 는 반복 고르기 > 화면에 기억 > 카드 저장하기 뒤 반복 저장
/// 시트를 그냥 닫으면 그대로 둠. 반복 저장만 실패하면 일과는 저장된 채 실패 팝업(E-SCHEDULE)
mixin CardReviewScheduleSend<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 이 화면에서 고른 반복 (아직 저장 전). null 이면 예약 없이 보냄
  RoutineSchedule? pickedRepeatSchedule;

  /// 예약 도구를 보이는가 (조건 2개: 보낸 복사본이 아닌 원본 일과, Pro 이거나 Pro 판매 중)
  bool get shouldShowScheduleTool {
    final routine = ref.watch(routineFlowProvider).routine;
    final isOriginalRoutine = routine != null && routine.sourceRoutineId == null;
    return isOriginalRoutine &&
        ref.watch(planAccessProvider).shouldShowEntryFor(PlanBenefit.routineSchedule);
  }

  /// 예약 도구에 PRO 배지를 붙이는가 (Free · 판매 중)
  bool get shouldShowScheduleProBadge =>
      ref.watch(planAccessProvider).shouldShowTeaserFor(PlanBenefit.routineSchedule);

  /// 예약 도구 이름: 고른 반복이 있으면 요약(`평일 오전 8:00`), 없으면 `예약`
  String get scheduleToolLabel {
    final picked = pickedRepeatSchedule;
    return picked == null
        ? context.l10n.cardReviewToolSchedule
        : routineScheduleSummaryLabel(context, picked);
  }

  /// 누름: Pro 아님 > Pro 안내 / Pro > 반복 고르기 > 고른 값 기억 (예약 안 하기면 비움, 그냥 닫으면 그대로)
  Future<void> openScheduleTool() async {
    final routine = ref.read(routineFlowProvider).routine;
    if (routine == null) return;
    if (!ref.read(planAccessProvider).canScheduleRoutines) {
      await openProOnlyNotice(context, ref, benefit: PlanBenefit.routineSchedule);
      return;
    }
    final pick = await RoutineScheduleSheet.pick(
      context,
      routine,
      pickedSchedule: pickedRepeatSchedule,
    );
    if (pick == null || !mounted) return;
    setState(() => pickedRepeatSchedule = pick.schedule);
  }

  /// 일과 저장 뒤 반복 저장 (저장으로 원본이 된 [savedRoutineId] 기준). 실패 팝업은 다 본 뒤 돌아옴
  Future<void> saveRepeatScheduleAfterSend(String? savedRoutineId, RoutineSchedule repeatSchedule) async {
    if (savedRoutineId == null) return;
    final failure = await ref
        .read(routineScheduleControllerProvider)
        .save(
          RoutineSchedule(
            routineId: savedRoutineId,
            weekdays: repeatSchedule.weekdays,
            hour: repeatSchedule.hour,
            minute: repeatSchedule.minute,
            isNotifyEnabled: repeatSchedule.isNotifyEnabled,
          ),
        );
    if (failure == null || !mounted) return;
    await showRoutineScheduleSaveFailure(context, ref, failure);
  }
}
