import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/state/busy_state_mixin.dart';
import '../../../core/widgets/elum_secondary_button.dart';
import '../../../core/widgets/pro_badge.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../../subscription/domain/plan_benefit.dart';
import '../application/routine_notifier.dart';
import '../application/routine_schedule_controller.dart';
import '../domain/routine_schedule.dart';
import 'widgets/routine_schedule_sheet.dart';

/// 카드 확인 예약 보내기: 저장 버튼 아래 보조 버튼 > Free 는 Pro 안내 · Pro 는 반복 고르기 > 저장(보내기) + 반복 저장
/// 시트를 닫으면 아무것도 안 함. 반복 저장만 실패하면 일과는 저장된 채 실패 팝업(E-SCHEDULE)
mixin CardReviewScheduleSend<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, BusyStateMixin<T> {
  /// 고른 반복을 들고 저장(보내기)하는 화면 동작
  Future<void> sendWithRepeatSchedule(RoutineSchedule repeatSchedule);

  /// 예약 보내기 버튼 (보일 조건 2개: 보낸 복사본이 아닌 원본 일과, Pro 이거나 Pro 판매 중). 아니면 null
  Widget? buildScheduleSendButton() {
    final routine = ref.watch(routineFlowProvider).routine;
    final access = ref.watch(planAccessProvider);
    final isOriginalRoutine = routine != null && routine.sourceRoutineId == null;
    if (!isOriginalRoutine || !access.shouldShowEntryFor(PlanBenefit.routineSchedule)) return null;
    return ElumSecondaryButton(
      label: context.l10n.cardReviewScheduleSend,
      trailing: access.shouldShowTeaserFor(PlanBenefit.routineSchedule) ? const ProBadge() : null,
      onTap: busy ? null : _openScheduleSend,
    );
  }

  /// 누름: Pro 아님 > Pro 안내 / Pro > 반복 고르기 > 고른 값으로 보내기 (닫으면 끝)
  Future<void> _openScheduleSend() async {
    final routine = ref.read(routineFlowProvider).routine;
    if (routine == null) return;
    if (!ref.read(planAccessProvider).canScheduleRoutines) {
      await openProOnlyNotice(context, ref, benefit: PlanBenefit.routineSchedule);
      return;
    }
    final repeatSchedule = await RoutineScheduleSheet.pick(context, routine);
    if (repeatSchedule == null || !mounted) return;
    await sendWithRepeatSchedule(repeatSchedule);
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
