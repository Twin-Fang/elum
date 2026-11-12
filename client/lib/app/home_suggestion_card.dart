import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/assets/app_assets.dart';
import '../core/l10n/batchim.dart';
import '../core/l10n/l10n_context.dart';
import '../core/router/routes.dart';
import '../core/widgets/home_notice_card.dart';
import '../features/guardian/domain/home_suggestion.dart';
import '../features/guardian/presentation/widgets/routine_schedule_sheet.dart';
import '../features/member/application/plan_access.dart';
import '../features/subscription/application/plan_paywall_entry.dart';
import '../features/subscription/domain/plan_benefit.dart';
import 'home_suggestion_provider.dart';

/// 보호자 홈 권유 카드: 권유 하나([homeSuggestionProvider])를 안내 카드 모양으로 그림. 보일지는 [homeNoticeChoiceProvider]
///
/// 누르면 종류별 이동: 자동 보내기 > 반복 시트(Free 는 요금제 화면), 이야기 올리기 > 올리기 화면, 일과 더 만들기 > [onCreateRoutine]
class HomeSuggestionCard extends ConsumerWidget {
  const HomeSuggestionCard({super.key, required this.onCreateRoutine});

  /// 일과 만들기 시작 (크레딧 확인 포함, 홈 버튼과 같은 길)
  final Future<void> Function() onCreateRoutine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestion = ref.watch(homeSuggestionProvider);
    if (suggestion == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final routineTitle = suggestion.routine.displayTitle;
    final batchim = batchimOf(routineTitle);
    final (tileAsset, title, body, actionLabel) = switch (suggestion.kind) {
      HomeSuggestionKind.autoSend => (
        AppAssets.homeNoticeAutoSend,
        l10n.homeSuggestionAutoSendTitle,
        l10n.homeSuggestionAutoSendBody(routineTitle, batchim, suggestion.sentDayCount),
        l10n.homeSuggestionAutoSendAction,
      ),
      HomeSuggestionKind.talkShare => (
        AppAssets.homeNoticeTalkShare,
        l10n.homeSuggestionTalkShareTitle,
        l10n.homeSuggestionTalkShareBody(routineTitle, batchim),
        l10n.homeSuggestionTalkShareAction,
      ),
      HomeSuggestionKind.createMore => (
        AppAssets.homeNoticeCreateMore,
        l10n.homeSuggestionCreateMoreTitle,
        l10n.homeSuggestionCreateMoreBody,
        l10n.homeSuggestionCreateMoreAction,
      ),
    };
    final history = ref.read(homeSuggestionHistoryProvider.notifier);

    return HomeNoticeCard(
      title: title,
      body: body,
      actionLabel: actionLabel,
      tileAsset: tileAsset,
      onAction: () async {
        await _openDestination(context, ref, suggestion);
        await history.markActedOn(suggestion);
      },
      onDismiss: () => history.markDismissed(suggestion),
      dismissLabel: l10n.homeSuggestionDismissLabel,
    );
  }

  Future<void> _openDestination(BuildContext context, WidgetRef ref, HomeSuggestion suggestion) {
    switch (suggestion.kind) {
      case HomeSuggestionKind.autoSend:
        // 반복은 Pro: 쓸 수 있으면 반복 시트, 아니면 반복 혜택을 위로 올린 요금제 화면
        if (ref.read(planAccessProvider).canScheduleRoutines) {
          return RoutineScheduleSheet.show(context, suggestion.routine);
        }
        return openPlanPaywall(context, ref, highlight: PlanBenefit.routineSchedule);
      case HomeSuggestionKind.talkShare:
        return context.push<void>(Routes.guardianTalkShare, extra: suggestion.routine.id);
      case HomeSuggestionKind.createMore:
        return onCreateRoutine();
    }
  }
}
