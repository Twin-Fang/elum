import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_error_view.dart';
import '../../../core/widgets/elum_scaffold.dart';
import '../../../shared/models/routine.dart';
import '../application/routine_notifier.dart';
import '../data/routine_repository.dart';

/// 임시저장 — 만들다 만 일과를 이어서 만든다 (Figma `설정_임시저장` 1045:4910).
///
/// **시안은 헤더만 있고 내용이 비어 있다.** 디자인이 아직 안 나왔으므로 이 앱에
/// 이미 있는 것들로만 짰다 — 목록은 보호자 홈과 같은 [RoutineSummaryTile]을 쓰고,
/// 빈 상태와 실패 상태는 공통 위젯을 쓴다. 새 시각 언어를 만들면 시안이 나왔을 때
/// 두 번 고치게 된다 (#349).
///
/// 서버의 `PENDING_REVIEW`가 곧 임시저장이다. **`승인 대기`라 부르지 않는다** —
/// 만들다 만 것이지 심사가 아니다 (용어 규칙).
class DraftRoutinesScreen extends ConsumerWidget {
  const DraftRoutinesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drafts = ref.watch(draftRoutinesProvider);
    final space = context.space;

    return ElumScaffold(
      onBack: () => context.pop(),
      // 시안(`1045:4910`)도 같은 네비게이션 제목이다.
      title: '임시저장',
      backTop: 67,
      horizontalPadding: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 40.h),
          Expanded(
            child: drafts.when(
              // 로딩과 0건을 **구분한다.** 같은 화면으로 두면 느린 연결에서
              // "없다"고 잘못 읽는다 (docs 예외처리 규칙).
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ElumErrorView(
                message: '임시저장을 불러오지 못했어요',
                errorCode: 'E-DRAFT',
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
                      separatorBuilder: (_, _) => SizedBox(height: space.sm),
                      itemBuilder: (context, i) {
                        final routine = list[i];
                        return _DraftTile(
                          routine: routine,
                          onTap: () => _resume(context, ref, routine),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
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

/// 임시저장 한 줄.
///
/// **보호자 홈의 [RoutineSummaryTile]을 쓰지 않는다.** 그 타일은 진행률 링·다시하기·
/// 예정일처럼 홈 화면의 데이터 모양을 전제하는데, 임시저장에는 셋 다 없다.
/// 실제로 얹어 보니 고정 높이 안에서 43 넘쳤다. 없는 것을 그리는 자리를 비워 두느니
/// 필요한 것만 담은 줄을 따로 둔다 (#349).
class _DraftTile extends StatelessWidget {
  const _DraftTile({required this.routine, required this.onTap});

  final Routine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: space.lg,
          vertical: space.md,
        ),
        decoration: BoxDecoration(
          color: colors.routineTileBg,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                routine.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.settingsTileLabel.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            // 누르면 무엇이 되는지 말로 적는다 — 화살표만 두면 열어 보기 전에는 모른다.
            Text(
              '이어서',
              style: context.typo.settingsTileLabel.copyWith(
                color: colors.textSecondary,
              ),
            ),
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
              '만들다 만 일과가 없어요',
              textAlign: TextAlign.center,
              style: context.typo.promptTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: space.sm),
            Text(
              '일과를 만들다 그만두면 여기에 남아요',
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
