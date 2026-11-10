import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/widgets/show_failure.dart';
import '../../application/routine_notifier.dart';
import '../../application/routine_providers.dart';

/// 화면 에러 코드 (일과를 못 열었을 때)
const weeklyReportCardEditErrorCode = 'E-WEEKLY-REPORT-EDIT';

/// 리포트의 `카드 고치기`: 원본 일과 찾기 > 검토 화면에 올리기 (일과관리 `카드 고치기`와 같은 길)
Future<void> openLibraryRoutineCardEdit(BuildContext context, WidgetRef ref, String libraryRoutineId) async {
  final l10n = context.l10n; // await 뒤에서 context 를 읽지 않으려고 미리 잡는다
  try {
    final library = await ref.read(routineLibraryProvider.future);
    if (!context.mounted) return;
    final routine = library.where((candidate) => candidate.id == libraryRoutineId).firstOrNull;
    if (routine == null) {
      await showFailureMessage(
        context,
        sentence: l10n.weeklyReportInsightStuckFixFailed,
        code: weeklyReportCardEditErrorCode,
      );
      return;
    }
    ref.read(routineFlowProvider.notifier).loadExisting(routine);
    await context.push(Routes.routineReview);
  } on Object catch (error) {
    if (!context.mounted) return;
    await showFailure(
      context,
      error,
      fallback: l10n.weeklyReportInsightStuckFixFailed,
      fallbackCode: weeklyReportCardEditErrorCode,
    );
  }
}
