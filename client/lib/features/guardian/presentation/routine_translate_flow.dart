import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/routine.dart';
import 'widgets/routine_translate_sheet.dart';

/// 다른 언어로 만들기 공통: 언어 시트 > 만들기 > 성공 토스트 · 실패 팝업(에러 코드)
/// 새로 만든 일과를 돌려준다. 닫았거나 실패면 null (원래 일과는 그대로)
Future<Routine?> translateRoutineWithSheet(
  BuildContext context,
  Routine routine,
) async {
  final l10n = context.l10n;
  final translateAttempt = await showRoutineTranslateSheet(context, routine);
  if (translateAttempt == null || !context.mounted) return null;
  final created = translateAttempt.value;
  if (created != null) {
    showElumToast(
      context,
      l10n.routineTranslateDone(
        routineTranslateLanguageLabel(l10n, created.language),
      ),
    );
    return created;
  }
  await showFailure(
    context,
    translateAttempt.failure,
    title: l10n.routineTranslateFailedTitle,
    fallback: l10n.routineTranslateFailedFallback,
    fallbackCode: 'E-LIB-TRANSLATE',
  );
  return null;
}
