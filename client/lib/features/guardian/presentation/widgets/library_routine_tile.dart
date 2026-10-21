import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/routine.dart';
import '../../application/library_talk_import_state.dart';
import 'card_image.dart';

/// 일과관리 격자 한 칸: 첫 카드 그림 + 이름 + 오늘 보냈으면 ✓ (#805)
///
/// 누르면 상세, 길게 누르면 빠른 메뉴. 휴대폰 바탕화면 앱 아이콘처럼 보이게 둔다.
/// 이야기에서 가져온 일과는 이름 아래 `이야기에서`, 아직 안 열어 봤으면 주황 테두리 + `새로` 배지.
class LibraryRoutineTile extends ConsumerWidget {
  const LibraryRoutineTile({
    super.key,
    required this.routine,
    required this.isSentToday,
    required this.onTap,
    this.onLongPress,
  });

  final Routine routine;

  /// 오늘 이룸이에게 이미 보냈는가 (오른쪽 아래 ✓)
  final bool isSentToday;
  final VoidCallback onTap;

  /// null 이면 길게 누르기를 바깥(끌기)에 맡긴다 (#807)
  final VoidCallback? onLongPress;

  /// 그림 칸 한 변 · 모서리 · ✓ 배지 한 변 (시안 1664:6876)
  static const iconSize = 68.0;
  static const iconRadius = 16.0;
  static const badgeSize = 22.0;

  /// 안 열어 본 가져온 일과의 테두리 두께
  static const _newOutlineWidth = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final isFromTalk = routine.talkPostId != null;
    final isNew =
        isFromTalk &&
        !ref.watch(talkImportedSeenRoutineIdsProvider).contains(routine.id);
    final label = [
      routine.displayTitle,
      if (isFromTalk) l10n.routineLibraryFromTalk,
      if (isNew) l10n.routineLibraryNewBadge,
      if (isSentToday) l10n.routineLibrarySentBadge,
    ].join(', ');

    return Semantics(
      label: label,
      hint: l10n.routineLibraryTileHint,
      button: true,
      excludeSemantics: true,
      child: AppPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        scaleDown: AppPressable.scaleIcon,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // 정사각형 — 가로세로 모두 .w
                // 테두리는 그림 위에 덧그린다 — 감싸면 두께만큼 그림이 밀린다
                Container(
                  foregroundDecoration: isNew
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(iconRadius.w),
                          border: Border.all(
                            color: colors.brandOrange,
                            width: _newOutlineWidth.w,
                          ),
                        )
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(iconRadius.w),
                    child: SizedBox.square(
                      dimension: iconSize.w,
                      child: LibraryRoutineThumbnail(routine: routine),
                    ),
                  ),
                ),
                if (isNew)
                  Positioned(
                    top: -space.xs.h / 2,
                    right: -space.xs.w / 2,
                    child: const _NewBadge(),
                  ),
                if (isSentToday)
                  Positioned(
                    right: -space.xs.w / 2,
                    bottom: -space.xs.w / 2,
                    child: LibrarySentBadge(size: badgeSize.w),
                  ),
              ],
            ),
            SizedBox(height: space.xs.h),
            // 이야기에서 온 일과는 이름 한 줄 + `이야기에서` 한 줄: 칸 높이(이름 두 줄)를 늘리지 않는다
            ContentLocale(
              language: routine.language,
              child: Text(
                routine.displayTitle,
                maxLines: isFromTalk ? 1 : 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.typo.libraryTileLabel.copyWith(
                  color: colors.libraryTileLabel,
                ),
              ),
            ),
            if (isFromTalk)
              Text(
                l10n.routineLibraryFromTalk,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.typo.libraryTileLabel.copyWith(
                  color: colors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `새로` 배지 (주황 바탕 + 흰 글자, 바탕색 테두리로 그림과 떨어뜨린다)
class _NewBadge extends StatelessWidget {
  const _NewBadge();

  static const _paddingH = 6.0;
  static const _paddingV = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _paddingH.w,
        vertical: _paddingV.h,
      ),
      decoration: BoxDecoration(
        color: colors.brandOrange,
        borderRadius: BorderRadius.circular(context.space.cardRadius.r),
        border: Border.all(color: colors.background, width: 2),
      ),
      child: Text(
        context.l10n.routineLibraryNewBadge,
        maxLines: 1,
        style: context.typo.caption.copyWith(color: colors.surface),
      ),
    );
  }
}

/// 일과 첫 카드 그림. 카드가 없거나 그림이 없으면 제목 첫 글자 (격자 칸 · 폴더 미리보기 · 묶음 목록 공통)
class LibraryRoutineThumbnail extends StatelessWidget {
  const LibraryRoutineThumbnail({super.key, required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final steps = routine.steps;
    final placeholder = _LetterThumbnail(title: routine.displayTitle);
    if (steps.isEmpty) return placeholder;
    final first = steps.first;
    // 그림을 받는 동안에도 칸 모양이 보이게 흰 바탕을 깔아 둔다 (비어 보이면 빠진 칸 같다)
    return ColoredBox(
      color: context.colors.surface,
      child: CardImage(
        routineId: routine.id,
        stepId: first.id,
        imagePath: first.imagePath,
        pictogramId: first.pictogramId,
        exampleImageId: first.exampleImageId,
        pictogramLabel: first.title,
        emptyBuilder: (_) => placeholder,
      ),
    );
  }
}

class _LetterThumbnail extends StatelessWidget {
  const _LetterThumbnail({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final letter = title.characters.isEmpty ? '' : title.characters.first;
    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Text(
          letter,
          style: context.typo.sectionTitle.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// 오늘 보냄 ✓ (민트 원 + 흰 체크, 바탕색 테두리로 그림과 떨어뜨린다)
class LibrarySentBadge extends StatelessWidget {
  const LibrarySentBadge({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.checkDone,
        shape: BoxShape.circle,
        border: Border.all(color: colors.background, width: 2),
      ),
      child: Icon(
        Icons.check_rounded,
        size: size * 0.65,
        color: colors.surface,
      ),
    );
  }
}
