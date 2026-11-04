import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/content_locale.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/elum_toast.dart';
import '../../../core/widgets/show_failure.dart';
import '../../guardian/application/library_talk_import_state.dart';
import '../../guardian/application/routine_manage_entry.dart';
import '../../profile/application/profile_session.dart';
import '../application/expert_routine_providers.dart';
import '../domain/expert_routine.dart';
import 'widgets/expert_routine_step_row.dart';

/// 전문가 일과 미리 보기: 설명 · 보상 > 카드 목록 > [일과관리에 넣기]
/// 넣으면 지금 보는 이룸이 일과관리 맨 앞에 들어가고, 일과관리 칸으로 옮겨 그 일과로 스크롤한다
/// 상태: 받는 중 / 실패(다시 하기 + 에러 코드) / 미리 보기. 넣기 실패는 팝업(에러 코드) 후 화면 유지
class ExpertRoutineDetailScreen extends ConsumerStatefulWidget {
  const ExpertRoutineDetailScreen({super.key, required this.expertRoutineId});

  final String expertRoutineId;

  @override
  ConsumerState<ExpertRoutineDetailScreen> createState() =>
      _ExpertRoutineDetailScreenState();
}

class _ExpertRoutineDetailScreenState
    extends ConsumerState<ExpertRoutineDetailScreen> {
  bool _isImporting = false;

  /// 머리 > 설명 · 설명 > 보상 · 보상 > 카드 라벨 · 라벨 > 카드 · 카드 사이
  static const _headerToSummary = 16.0;
  static const _summaryToReward = 8.0;
  static const _metaToCards = 24.0;
  static const _labelToCards = 8.0;
  static const _stepGap = 8.0;
  static const _listBottom = 24.0;

  /// 넣기: 이룸이 확인 > 서버 > 일과관리 칸으로 (스크롤 대상 지정) > 토스트
  Future<void> _import(ExpertRoutineDetail detail) async {
    if (_isImporting) return;
    final l10n = context.l10n;
    final profile = ref.read(activeProfileProvider);
    if (profile == null) {
      await showElumDialog<void>(
        context: context,
        title: l10n.expertRoutineNoElumi,
        code: ExpertRoutineScreenCodes.noElumi,
        icon: ElumDialogIcon.alert,
        actions: [
          ElumDialogAction(label: l10n.commonConfirm, tone: ElumDialogTone.danger),
        ],
      );
      return;
    }
    setState(() => _isImporting = true);
    // 화면을 옮긴 뒤에도 쓸 것들을 먼저 잡는다
    final container = ProviderScope.containerOf(context);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final imported = await ref
          .read(expertRoutineImportControllerProvider)
          .importToLibrary(detail.id, profileId: profile.id);
      container
          .read(libraryScrollTargetRoutineIdProvider.notifier)
          .request(imported.routineId);
      // 무효화된 목록을 build 밖에서 먼저 계산 (일과관리 build 중 갱신 경고 방지)
      readRoutineManageSourcesBeforeEntering(container);
      router.go(Routes.guardianManage);
      showElumToastOn(messenger, l10n.expertRoutineImportDone(profile.displayName));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      await showFailure(
        context,
        e,
        title: l10n.expertRoutineImportFailedTitle,
        fallback: l10n.expertRoutineLoadFailed,
        fallbackCode: ExpertRoutineScreenCodes.importToLibrary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final detail = ref.watch(expertRoutineDetailProvider(widget.expertRoutineId));
    final loaded = detail.value;

    return ElumScaffold(
      onBack: context.popOrHome,
      title: loaded?.title ?? l10n.expertRoutineListTitle,
      backTop: 67,
      horizontalPadding: 16,
      bottomButton: loaded == null || loaded.steps.isEmpty
          ? null
          : ElumButton(
              label: l10n.expertRoutineImport,
              loading: _isImporting,
              onPressed: _isImporting ? null : () => _import(loaded),
            ),
      child: switch (detail) {
        AsyncData(value: final routine) => _body(routine),
        AsyncError(:final error) => ElumStateBody(
          child: ElumErrorView.failure(
            error,
            fallback: l10n.expertRoutineLoadFailed,
            fallbackCode: ExpertRoutineScreenCodes.detail,
            onRetry: () => ref.invalidate(
              expertRoutineDetailProvider(widget.expertRoutineId),
            ),
          ),
        ),
        _ => const ElumStateBody.loading(),
      },
    );
  }

  Widget _body(ExpertRoutineDetail detail) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;
    final summary = detail.summary;
    final reward = detail.rewardText;
    return ListView(
      padding: EdgeInsets.only(bottom: _listBottom.h),
      children: [
        SizedBox(height: _headerToSummary.h),
        if (summary != null)
          ContentLocale(
            language: detail.language,
            child: Text(
              summary,
              style: typo.talkPostNote.copyWith(color: colors.talkMetaText),
            ),
          ),
        if (reward != null) ...[
          SizedBox(height: _summaryToReward.h),
          ContentLocale(
            language: detail.language,
            child: Text(
              l10n.expertRoutineReward(reward),
              style: typo.talkPostNote.copyWith(color: colors.talkMetaText),
            ),
          ),
        ],
        SizedBox(height: _metaToCards.h),
        Text(
          l10n.expertRoutineCardsSection,
          style: typo.talkPostTitle.copyWith(color: colors.talkTitleText),
        ),
        SizedBox(height: _labelToCards.h),
        for (var index = 0; index < detail.steps.length; index++) ...[
          if (index > 0) SizedBox(height: _stepGap.h),
          ExpertRoutineStepRow(
            step: detail.steps[index],
            number: index + 1,
            language: detail.language,
          ),
        ],
      ],
    );
  }
}
