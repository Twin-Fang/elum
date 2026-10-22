import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/min_tap_target.dart';
import '../../../../shared/models/routine.dart';
import '../../../talk/application/talk_my_shared_posts_provider.dart';
import '../../application/routine_providers.dart';
import '../../application/talk_share_hint_state.dart';

/// 홈 끝낸 일과 카드 아래 링크: `📖 이야기에 공유해 보기 ›` + ✕
///
/// 조건 4개: 끝낸 일과, 원본이 예시·이야기에서 온 일과가 아님, 원본이 아직 안 올라감, 닫은 적 없음
/// 원본은 일과관리 목록에서 찾고, 목록이 아직 없거나 원본이 없으면 숨긴다
class TalkShareHintLink extends ConsumerWidget {
  const TalkShareHintLink({super.key, required this.routine});

  final Routine routine;

  /// 이야기 글은 원본 일과 기준이라 오늘 복사본이면 원본 id 로 본다
  String get _originalRoutineId => routine.sourceRoutineId ?? routine.id;

  /// 원본 일과가 올릴 수 있는 일과인가 (오늘 복사본은 예시·가져온 표시가 없어서 원본 기준으로 본다)
  bool _isOriginalShareable(WidgetRef ref, String originalRoutineId) {
    final libraryRoutines = ref.watch(routineLibraryProvider).value;
    if (libraryRoutines == null) return false;
    final original = libraryRoutines
        .where((libraryRoutine) => libraryRoutine.id == originalRoutineId)
        .firstOrNull;
    if (original == null) return false;
    return !original.isExample && original.talkPostId == null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final originalRoutineId = _originalRoutineId;
    if (!_isOriginalShareable(ref, originalRoutineId)) {
      return const SizedBox.shrink();
    }
    if (ref
        .watch(talkShareHintDismissedRoutineIdsProvider)
        .contains(originalRoutineId)) {
      return const SizedBox.shrink();
    }

    // 불러오는 동안은 숨기고(깜빡임 방지), 실패하면 빈 맵으로 보고 보여 준다
    final sharedPosts = ref.watch(talkMySharedPostsProvider);
    if (sharedPosts.isLoading && !sharedPosts.hasValue) {
      return const SizedBox.shrink();
    }
    final sharedPostIdBySourceRoutineId = sharedPosts.value ?? const {};
    if (sharedPostIdBySourceRoutineId.containsKey(originalRoutineId)) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final colors = context.colors;
    final space = context.space;
    return Padding(
      padding: EdgeInsets.only(top: space.xs.h),
      child: Row(
        children: [
          Expanded(
            child: AppPressable(
              onTap: () => context.push(
                Routes.guardianTalkShare,
                extra: originalRoutineId,
              ),
              scaleDown: AppPressable.scaleCard,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: space.xs.w,
                  vertical: space.xs.h,
                ),
                child: Text(
                  l10n.talkShareHint,
                  style: context.typo.caption.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          AppPressable(
            onTap: () => ref
                .read(talkShareHintDismissedRoutineIdsProvider.notifier)
                .dismiss(originalRoutineId),
            scaleDown: AppPressable.scaleIcon,
            semanticLabel: l10n.commonClose,
            child: MinTapTarget(
              child: SvgPicture.asset(
                AppAssets.iconClose,
                width: space.md.w,
                height: space.md.w,
                excludeFromSemantics: true,
                colorFilter: ColorFilter.mode(
                  colors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
