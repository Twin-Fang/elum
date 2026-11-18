import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/elum_bottom_sheet.dart';
import '../../../core/widgets/elum_empty_state.dart';
import '../../../shared/models/routine.dart';
import '../../child/application/child_routine_notifier.dart';
import '../application/home_routines.dart';
import '../application/routine_notifier.dart';
import 'card_export/open_card_export.dart';
import 'widgets/routine_detail_sheet.dart';

/// 가로 태블릿 홈 오른쪽 칸: 고른 오늘 일과의 상세(시트와 같은 내용, 화면 칸 안) > 카드 고치기 · 받기 (#1455)
/// 오늘 일과가 없으면 첫 일과 안내
class GuardianHomeDetailPane extends ConsumerWidget {
  const GuardianHomeDetailPane({super.key, required this.routine});

  /// 상세를 보일 일과. null 이면 안내
  final Routine? routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routine = this.routine;
    if (routine == null) {
      final l10n = context.l10n;
      return Center(
        child: ElumEmptyState(
          size: ElumEmptyStateSize.inline,
          illustrationAsset: AppAssets.emptyStateNoRoutines,
          title: l10n.guardianHomeDetailEmptyTitle,
        ),
      );
    }
    // 같은 기기에서 방금 끝낸 것도 끝낸 일과로 (오늘 목록과 같은 기준)
    final isFinished =
        routine.isFinished || routineProgress(routine, ref.watch(childRoutineProvider)) >= 1;
    return ElumSheetPresentation(
      isSidePanel: false,
      isInlinePane: true,
      child: RoutineDetailSheet(
        // 일과가 바뀌면 시트 상태(순서·이름)를 새로
        key: ValueKey(routine.id),
        routine: routine,
        isFinished: isFinished,
        onAction: (action) => _onAction(context, ref, routine, action),
      ),
    );
  }

  /// 오늘 일과 상세의 버튼: 카드 고치기 > 검토 화면, 받기 > 받기 화면 (그 밖은 오늘 일과에 없음)
  void _onAction(BuildContext context, WidgetRef ref, Routine routine, RoutineSheetAction action) {
    switch (action) {
      case RoutineSheetAction.edit:
        ref.read(routineFlowProvider.notifier).loadExisting(routine);
        context.push(Routes.routineReview);
      case RoutineSheetAction.export:
        openCardExport(context, routine);
      case RoutineSheetAction.rerun || RoutineSheetAction.send || RoutineSheetAction.more:
        break;
    }
  }
}
