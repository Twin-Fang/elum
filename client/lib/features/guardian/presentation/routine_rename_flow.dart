import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/routine_rename_sheet.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/routine.dart';
import '../application/routine_library_controller.dart';

/// 일과 이름 바꾸기 공통 (일과관리 · 상세 시트 · 카드 확인): 이름 시트 > 저장 > 성공 토스트 · 실패 팝업
/// 바뀐 일과를 돌려준다. 닫았거나 실패면 null (화면의 제목은 그대로)
///
/// [runBusy] 를 주면 저장하는 동안 그 화면의 바쁨 표시로 감싼다
Future<Routine?> renameRoutineWithSheet(
  BuildContext context,
  WidgetRef ref, {
  required String routineId,
  required String currentTitle,
  Future<Attempt<Routine>?> Function(
    Future<Attempt<Routine>> Function() task,
  )?
  runBusy,
}) async {
  final l10n = context.l10n;
  final title = await showRoutineRenameSheet(
    context,
    currentTitle: currentTitle,
  );
  if (title == null || !context.mounted) return null;

  Future<Attempt<Routine>> rename() =>
      ref.read(routineLibraryControllerProvider).rename(routineId, title);
  final renameAttempt = runBusy == null ? await rename() : await runBusy(rename);
  if (renameAttempt == null || !context.mounted) return null;

  if (renameAttempt.isOk) {
    showElumToast(context, l10n.routineLibraryRenamed);
    return renameAttempt.value;
  }
  await showFailure(
    context,
    renameAttempt.failure,
    title: l10n.routineLibraryRenameFailedTitle,
    fallback: l10n.routineLibraryActionFailedFallback,
    fallbackCode: 'E-LIB-RENAME',
  );
  return null;
}
