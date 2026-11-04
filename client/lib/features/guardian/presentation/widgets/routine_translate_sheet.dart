import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/network/app_failure.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/settings_group.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../../shared/models/routine.dart';
import '../../../credit/application/credit_costs.dart';
import '../../application/routine_library_controller.dart';
import '../../application/routine_translate_targets.dart';

/// 다른 언어로 만들기 시트: 언어 고르기 > 그 줄에서 진행 표시 > 결과([Attempt])를 돌려주며 닫힘
///
/// 진행 중에는 닫히지 않는다 (응답을 못 받아도 서버는 사본을 만들어 목록에 생기지만, 결과를 알려 줄 곳이 사라짐).
/// 닫았으면 null.
Future<Attempt<Routine>?> showRoutineTranslateSheet(
  BuildContext context,
  Routine routine,
) => showElumSheet<Attempt<Routine>>(
  context: context,
  builder: (_) => _RoutineTranslateSheet(routine: routine),
);

/// 언어 코드 > 고르는 줄 이름 (그 언어를 모르는 보호자도 알아보게 화면 언어 이름 + 그 언어 이름)
String routineTranslateLanguageLabel(AppLocalizations l10n, String language) =>
    switch (language) {
      'ko' => l10n.routineTranslateLanguageKo,
      'en' => l10n.routineTranslateLanguageEn,
      _ => language,
    };

class _RoutineTranslateSheet extends ConsumerStatefulWidget {
  const _RoutineTranslateSheet({required this.routine});

  final Routine routine;

  @override
  ConsumerState<_RoutineTranslateSheet> createState() =>
      _RoutineTranslateSheetState();
}

class _RoutineTranslateSheetState
    extends ConsumerState<_RoutineTranslateSheet> {
  /// 지금 만드는 언어. null 이면 고르는 중
  String? _translatingLanguage;

  bool get _isTranslating => _translatingLanguage != null;

  Future<void> _translate(String language) async {
    if (_isTranslating) return;
    setState(() => _translatingLanguage = language);
    final translateAttempt = await ref
        .read(routineLibraryControllerProvider)
        .translate(widget.routine.id, language);
    if (!mounted) return;
    Navigator.of(context).pop(translateAttempt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final costs = ref.watch(creditCostsProvider);
    final targets = routineTranslateTargetsOf(widget.routine);
    // 안내 줄: 진행 중 > 기다림, 크레딧 켜짐 > 쓰는 크레딧, 꺼짐 > 없음
    final footer = _isTranslating
        ? l10n.routineTranslateInProgress
        : costs == null
        ? null
        : l10n.routineTranslateCreditNote(costs.routine);
    return PopScope(
      canPop: !_isTranslating,
      child: ElumSheetFrame(
        title: l10n.routineTranslateSheetTitle,
        description: l10n.routineTranslateSheetDescription,
        child: SettingsGroup(
          footer: footer,
          children: [
            for (final language in targets)
              SettingsTile(
                label: routineTranslateLanguageLabel(l10n, language),
                loading: _translatingLanguage == language,
                onTap: _isTranslating ? null : () => _translate(language),
              ),
          ],
        ),
      ),
    );
  }
}
