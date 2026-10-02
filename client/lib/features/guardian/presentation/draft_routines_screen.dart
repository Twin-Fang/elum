import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/ad_banner_slot.dart';
import '../../../core/ads/ad_ids.dart';
import '../../../core/l10n/content_locale.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../shared/models/routine.dart';
import '../application/routine_notifier.dart';
import '../data/routine_repository.dart';
import 'widgets/routine_swipe_actions.dart';

/// 임시저장 — 만들다 만 일과를 이어서 만든다 (Figma `설정_임시저장` 1045:4910 ·
/// 밀어서 삭제 `설정_임시저장_삭제` 1274:9262, #496).
///
/// 줄은 361×68 이고 제목 아래에 `완료 시 · 보상` 을 적는다. 오른쪽에 흰 `이어서`
/// 알약이 서고, 줄을 왼쪽으로 밀면 삭제 하나가 나온다(수정은 없다 — 이어서 만들면
/// 고칠 수 있다). 지우기 전에 한 번 묻는다. 빈 상태와 실패 상태는 공통 위젯을 쓴다.
///
/// 서버의 `PENDING_REVIEW`가 곧 임시저장이다. **`승인 대기`라 부르지 않는다** —
/// 만들다 만 것이지 심사가 아니다 (용어 규칙).
class DraftRoutinesScreen extends ConsumerStatefulWidget {
  const DraftRoutinesScreen({super.key});

  @override
  ConsumerState<DraftRoutinesScreen> createState() =>
      _DraftRoutinesScreenState();
}

class _DraftRoutinesScreenState extends ConsumerState<DraftRoutinesScreen> {
  /// 지금 밀려 열려 있는 줄. 둘이 동시에 열리면 어느 버튼이 누구 것인지 모른다.
  String? _openId;

  /// 지우는 중인 줄. 두 번 눌러 같은 일과를 두 번 지우지 않게 잠근다.
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    // **들어올 때마다 새로 받는다** (#387). 전체 목록은 keepAlive 라 한 번 받은 것을
    // 계속 준다 — 다른 휴대폰에서 만들다 둔 것, 로딩 중에 나가 뒤늦게 생긴 것이
    // 안 보인다. 받는 동안에는 직전 목록을 그대로 보여주므로 깜빡이지 않는다.
    //
    // 서버 전용 `GET /api/routines/drafts` 는 쓰지 않는다. 목록이 하나 더 생기면
    // 셋(오늘·지난·전체)과 함께 무효화해야 하는 넷째가 되고, 한쪽만 갱신되는
    // 일(#353)이 다시 생긴다. 전체 목록을 걸러도 한 보호자의 일과는 많지 않다.
    //
    // 첫 프레임 뒤로 미룬다 — initState 는 빌드 중이라 여기서 무효화하면 이미
    // 목록을 보고 있는 위 화면까지 빌드 도중에 다시 그리라는 요청이 된다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(myRoutinesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(draftRoutinesProvider);
    final space = context.space;

    return ElumScaffold(
      onBack: () => context.pop(),
      // 시안(`1045:4910`)도 같은 네비게이션 제목이다.
      title: context.l10n.draftRoutinesTitle,
      backTop: 67,
      horizontalPadding: 16,
      // 하단 배너(#281). 로드 전·실패 시 높이 0이라 자리를 남기지 않는다.
      bottomBanner: const AdBannerSlot(placement: AdPlacement.bannerDrafts),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 시안 — 첫 줄 윗변이 y=131 (머리 영역 끝 107 에서 24, 1045:4910)
          SizedBox(height: 24.h),
          Expanded(
            child: drafts.when(
              // 로딩과 0건을 **구분한다.** 같은 화면으로 두면 느린 연결에서
              // "없다"고 잘못 읽는다 (docs 예외처리 규칙).
              loading: () => const Center(child: CircularProgressIndicator()),
              // 서버가 이유를 알려줬으면 그 문구가 아래 기본 문구를 이긴다 (#352).
              error: (e, _) => ElumErrorView.failure(
                e,
                fallback: context.l10n.draftRoutinesLoadFailedFallback,
                fallbackCode: 'E-DRAFT',
                onRetry: () => ref.invalidate(myRoutinesProvider),
                // 제목 아래 남는 자리에 들어간다. 큰 쪽은 일러스트까지 세워
                // 이 자리에서 넘친다.
                compact: true,
              ),
              data: (list) => list.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      padding: EdgeInsets.only(bottom: space.xl),
                      itemCount: list.length,
                      // 시안 — 줄과 줄 사이 8 (131 + 68 → 207)
                      separatorBuilder: (_, _) => SizedBox(height: 8.h),
                      itemBuilder: (context, i) {
                        final routine = list[i];
                        return RoutineSwipeActions(
                          isOpen: _openId == routine.id,
                          onOpenChanged: (open) => setState(
                            () => _openId = open ? routine.id : null,
                          ),
                          onDelete: () => _delete(routine),
                          // 시안(1274:9262) — 버튼 끝이 줄 끝(377)보다 2 안쪽이다
                          endInset: 2,
                          deleteLabel: context.l10n.draftRoutinesDeleteLabel,
                          // 지우는 중에는 밀리지 않는다
                          enabled: _deletingId == null,
                          child: _DraftTile(
                            routine: routine,
                            highlighted: _openId == routine.id,
                            // 열려 있을 때 누르면 이어서가 아니라 닫는다
                            onTap: () => _openId == routine.id
                                ? setState(() => _openId = null)
                                : _resume(context, ref, routine),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 임시저장 지우기 — **먼저 묻고** 지운다 (#496).
  ///
  /// 바로 지우면 잘못 밀어도 되돌릴 길이 없다. 서버는 일과 삭제 API 로 지운다(임시저장도
  /// 일과다). 실패하면 줄을 그대로 두고 에러 코드를 보여준다.
  Future<void> _delete(Routine routine) async {
    if (_deletingId != null) return;
    final confirmed = await showElumDialog<bool>(
      context: context,
      title: context.l10n.draftRoutinesDeleteConfirmTitle,
      icon: ElumDialogIcon.trash,
      actions: [
        ElumDialogAction(
          label: context.l10n.commonCancel,
          value: false,
          tone: ElumDialogTone.neutral,
        ),
        ElumDialogAction(
          label: context.l10n.draftRoutinesDeleteAction,
          value: true,
          tone: ElumDialogTone.danger,
        ),
      ],
    );
    // 바깥을 눌러 닫으면 null — 취소로 다룬다
    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = routine.id);
    final failure = await ref.read(routineRepositoryProvider).delete(routine.id);
    if (!mounted) return;
    setState(() {
      _deletingId = null;
      if (failure == null) _openId = null;
    });
    if (failure != null) {
      await showFailure(
        context,
        failure,
        title: context.l10n.draftRoutinesDeleteFailedTitle,
        fallback: context.l10n.draftRoutinesDeleteFailedFallback,
        fallbackCode: 'E-DRAFT-DEL',
      );
      return;
    }
    // 지금 이어 만들던 일과를 지웠다면 흐름에 남은 것도 함께 치운다
    if (ref.read(routineFlowProvider).routine?.id == routine.id) {
      ref.read(routineFlowProvider.notifier).reset();
    }
    ref.refreshRoutines();
  }

  /// 이어서 만들기 — 카드확인 화면으로 보낸다.
  ///
  /// 그 사이 다른 기기에서 지워졌을 수 있다. 목록을 다시 받아 두어 돌아왔을 때
  /// 없어진 줄이 남아 있지 않게 한다.
  void _resume(BuildContext context, WidgetRef ref, Routine routine) {
    ref.read(routineFlowProvider.notifier).resumeDraft(routine);
    context.push(Routes.routineReview);
  }
}

/// 임시저장 한 줄 (Figma 1045:4910 · 1274:9262).
///
/// **보호자 홈의 [RoutineSummaryTile]을 쓰지 않는다.** 그 타일은 진행률 링·다시하기·
/// 예정일처럼 홈 화면의 데이터 모양을 전제하는데, 임시저장에는 셋 다 없다.
/// 글자 크기와 색은 홈 타일의 토큰을 그대로 쓴다 — 시안도 같은 값이다.
class _DraftTile extends StatelessWidget {
  const _DraftTile({
    required this.routine,
    required this.onTap,
    this.highlighted = false,
  });

  final Routine routine;
  final VoidCallback onTap;

  /// 밀려 열려 있다. 줄이 한 단계 어두워진다 (`#D7D3D1`).
  final bool highlighted;

  /// Figma 실측 — 줄 높이 68 · 글 왼쪽 18 · 제목과 보상 줄 8.
  /// 글 두 줄(16+8+13)이 68 한가운데 서면 제목 윗변이 시안 y=16 이다.
  static const _height = 68.0;
  static const _padLeft = 18.0;
  static const _titleToMeta = 8.0;

  /// `완료 시`(18~55)와 보상(61~) 사이
  static const _labelGap = 6.0;

  /// `이어서` 알약의 오른쪽 여백. 시안은 x=268 에서 시작해 글자 폭만큼 선다.
  static const _padRight = 11.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    // 보상을 안 정했으면 줄을 감추지 않고 `미설정` 이라 적는다 (시안 1274:9276).
    final reward = routine.hasReward
        ? routine.rewardDisplay
        : context.l10n.draftRoutinesRewardUnset;

    final rewardText = Text(
      reward,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: typo.routineTileReward.copyWith(color: colors.routineTileReward),
    );

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: _height.h,
        decoration: BoxDecoration(
          color: highlighted ? colors.routineTileSwiped : colors.routineTileBg,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Row(
          children: [
            SizedBox(width: _padLeft.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentLocale(
                    language: routine.language,
                    child: Text(
                      routine.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.routineTileTitle.copyWith(
                        color: colors.chipLabel,
                      ),
                    ),
                  ),
                  SizedBox(height: _titleToMeta.h),
                  Row(
                    children: [
                      Text(
                        context.l10n.draftRoutinesRewardLabel,
                        style: typo.routineTileMeta.copyWith(
                          color: colors.routineTileLabel,
                        ),
                      ),
                      SizedBox(width: _labelGap.w),
                      Expanded(
                        // 보상 글만 일과 언어다. `미설정` 은 화면 문구라 따르지 않는다.
                        child: routine.hasReward
                            ? ContentLocale(
                                language: routine.language,
                                child: rewardText,
                              )
                            : rewardText,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 누르면 무엇이 되는지 말로 적는다 — 줄 전체가 눌린다
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.l10n.draftRoutinesResume,
                style: typo.routineSectionLabel.copyWith(
                  color: colors.chipLabel,
                ),
              ),
            ),
            SizedBox(width: _padRight.w),
          ],
        ),
      ),
    );
  }
}

/// 0건. **로딩과 다른 화면이어야 한다.**
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: space.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.l10n.draftRoutinesEmptyTitle,
              textAlign: TextAlign.center,
              style: context.typo.promptTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: space.sm),
            Text(
              context.l10n.draftRoutinesEmptyBody,
              textAlign: TextAlign.center,
              style: context.typo.promptBody.copyWith(
                color: colors.promptMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
