import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/batchim.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/app_celebration.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../application/guardian_child_identity.dart';
import '../application/routine_done_summary.dart';
import '../application/routine_providers.dart';
import 'widgets/routine_done_details.dart';

/// 이룸이가 끝낸 일과 축하 (완료 알림이 엶): 그림 튐 > `하늘이가 일과를 끝냈어요` > 바로 칭찬 한 줄 > 별 수 셈 > 끝낸 일과 이름
/// 상태 4가지: 불러오는 중 · 실패 (다시 시도 + 코드) · 지워진 일과 (홈으로 + 코드) · 축하
class RoutineDoneCelebrationScreen extends ConsumerWidget {
  const RoutineDoneCelebrationScreen({super.key, required this.routineId});

  /// 알림의 일과 id (비면 지워진 일과와 같은 안내)
  final String routineId;

  /// 목록 실패 · 일과를 못 찾음 코드
  static const _loadFailedCode = 'E-DONE-LOAD';
  static const _notFoundCode = 'E-DONE-GONE';

  void _goHome(BuildContext context) => context.go(Routes.guardian);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summaryAsync = ref.watch(routineDoneSummaryProvider(routineId));
    final summary = summaryAsync.value;
    return ElumScaffold(
      onBack: context.popOrHome,
      bottomButton: ElumButton(label: l10n.commonGoHome, onPressed: () => _goHome(context)),
      child: switch (summaryAsync) {
        AsyncData() when summary != null => ElumStateBody(child: _celebration(context, ref, summary)),
        AsyncData() => ElumStateBody(
          child: ElumErrorView(
            message: l10n.routineDoneNotFound,
            description: l10n.routineDoneNotFoundHint,
            errorCode: _notFoundCode,
          ),
        ),
        AsyncError(:final error) => ElumStateBody(
          child: ElumErrorView.failure(
            error,
            fallback: l10n.routineDoneLoadFailed,
            fallbackCode: _loadFailedCode,
            onRetry: ref.refreshRoutines,
          ),
        ),
        _ => const ElumStateBody.loading(),
      },
    );
  }

  /// 축하 장면 > 별 · 일과 이름 (축하 연출 뒤에 셈)
  Widget _celebration(BuildContext context, WidgetRef ref, RoutineDoneSummary summary) {
    final l10n = context.l10n;
    final name = ref.watch(guardianChildIdentityProvider).name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppCelebration(
          illustrationAsset: AppAssets.celebrationElumiCompleted,
          title: l10n.guardianRoutineDoneTitle(name, batchimOf(name)),
          reasonText: l10n.routineDonePraiseHint,
        ),
        RoutineDoneDetails(summary: summary),
      ],
    );
  }
}
