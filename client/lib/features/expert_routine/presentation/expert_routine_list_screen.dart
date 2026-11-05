import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/pop_or_home.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/elum_state_body.dart';
import '../../../core/widgets/pro_teaser.dart';
import '../../guardian/domain/routine_template.dart';
import '../../member/application/plan_access.dart';
import '../../subscription/application/plan_paywall_entry.dart';
import '../application/expert_routine_providers.dart';
import '../domain/expert_routine.dart';
import 'widgets/expert_routine_category_chips.dart';
import 'widgets/expert_routine_tile.dart';

/// 전문가 일과 목록 (일과관리 > 전문가 일과, Pro): 안내 한 줄 > 분류 칩 > 목록, 누르면 미리 보기
/// 상태: 받는 중 / 0건(글만 든 웜그레이 줄) / 실패(다시 하기 + 에러 코드) / 목록
/// Free · 판매 중: 목록을 받지 않고 흐린 견본 목록 + `Pro로 보기`
class ExpertRoutineListScreen extends ConsumerStatefulWidget {
  const ExpertRoutineListScreen({super.key});

  @override
  ConsumerState<ExpertRoutineListScreen> createState() =>
      _ExpertRoutineListScreenState();
}

class _ExpertRoutineListScreenState
    extends ConsumerState<ExpertRoutineListScreen> {
  /// 고른 분류. null 이면 전체
  RoutineTemplateCategory? _category;

  /// 머리 > 안내 · 안내 > 칩 · 칩 > 목록 · 줄 사이 (design-language 같은 묶음 안 줄 사이 8, 섹션 라벨 > 내용 16)
  static const _headerToHint = 16.0;
  static const _hintToChips = 16.0;
  static const _chipsToList = 16.0;
  static const _tileGap = 8.0;
  static const _listBottom = 24.0;

  void _openDetail(ExpertRoutineSummary routine) =>
      context.push(Routes.guardianExpertRoutineOf(routine.id));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final access = ref.watch(planAccessProvider);
    if (access.shouldShowTeaserFor(canUseFeature: access.canImportExpertRoutines)) {
      return _proTeaserScaffold(context);
    }
    final routines = ref.watch(expertRoutineListProvider(_category));

    return ElumScaffold(
      onBack: context.popOrHome,
      title: l10n.expertRoutineListTitle,
      backTop: ElumScaffold.settingsBackTop,
      horizontalPadding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: _headerToHint.h),
          Text(
            l10n.expertRoutineListHint,
            style: context.typo.talkGuide.copyWith(color: colors.talkMetaText),
          ),
          SizedBox(height: _hintToChips.h),
          ExpertRoutineCategoryChips(
            selectedCategory: _category,
            onSelected: (category) => setState(() => _category = category),
          ),
          SizedBox(height: _chipsToList.h),
          Expanded(
            child: switch (routines) {
              AsyncData(value: final summaries) when summaries.isEmpty => const _EmptyRow(),
              AsyncData(value: final summaries) => ListView.separated(
                padding: EdgeInsets.only(bottom: _listBottom.h),
                itemCount: summaries.length,
                separatorBuilder: (_, _) => SizedBox(height: _tileGap.h),
                itemBuilder: (context, index) => ExpertRoutineTile(
                  key: ValueKey(summaries[index].id),
                  routine: summaries[index],
                  onTap: () => _openDetail(summaries[index]),
                ),
              ),
              AsyncError(:final error) => ElumStateBody(
                child: ElumErrorView.failure(
                  error,
                  fallback: l10n.expertRoutineLoadFailed,
                  fallbackCode: ExpertRoutineScreenCodes.list,
                  onRetry: () =>
                      ref.invalidate(expertRoutineListProvider(_category)),
                ),
              ),
              _ => const ElumStateBody.loading(),
            },
          ),
        ],
      ),
    );
  }
}

extension on _ExpertRoutineListScreenState {
  /// Free 견본: 안내 한 줄 > 흐린 견본 줄 3개 (실제 전문가 일과를 받지 않음)
  Widget _proTeaserScaffold(BuildContext context) {
    final l10n = context.l10n;
    final samples = [
      (id: 'sample-morning', title: l10n.proTeaserSampleRoutineMorning, stepCount: 5),
      (id: 'sample-brush', title: l10n.proTeaserSampleRoutineBrush, stepCount: 4),
      (id: 'sample-bag', title: l10n.proTeaserSampleRoutineBag, stepCount: 3),
    ];
    return ElumScaffold(
      onBack: context.popOrHome,
      title: l10n.expertRoutineListTitle,
      backTop: ElumScaffold.settingsBackTop,
      horizontalPadding: 16,
      child: ListView(
        padding: EdgeInsets.only(
          top: _ExpertRoutineListScreenState._headerToHint.h,
          bottom: _ExpertRoutineListScreenState._listBottom.h,
        ),
        children: [
          ProTeaser(
            benefit: l10n.proTeaserExpertRoutineBenefit,
            onUnlock: () => openPlanPaywall(context, ref),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final sample in samples) ...[
                  ExpertRoutineTile(
                    routine: ExpertRoutineSummary(
                      id: sample.id,
                      title: sample.title,
                      stepCount: sample.stepCount,
                      summary: l10n.proTeaserSampleExpertSummary,
                    ),
                    onTap: () {},
                  ),
                  SizedBox(height: _ExpertRoutineListScreenState._tileGap.h),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 0건: 보호자 빈 상태 결 — 그림 없이 글만 든 웜그레이 줄 (시안 217:2655)
class _EmptyRow extends StatelessWidget {
  const _EmptyRow();

  static const _padding = 20.0;
  static const _lineGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(_padding.w),
        decoration: BoxDecoration(
          color: colors.editChipBg,
          borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.expertRoutineEmpty,
              style: context.typo.talkPostTitle.copyWith(color: colors.talkTitleText),
            ),
            SizedBox(height: _lineGap.h),
            Text(
              l10n.expertRoutineEmptyHint,
              style: context.typo.talkPostNote.copyWith(color: colors.talkMetaText),
            ),
          ],
        ),
      ),
    );
  }
}
