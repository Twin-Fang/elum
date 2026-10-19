import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../shared/models/routine.dart';
import 'card_image.dart';

/// 일과관리 격자 한 칸: 첫 카드 그림 + 이름 + 오늘 보냈으면 ✓ (#805)
///
/// 누르면 상세, 길게 누르면 빠른 메뉴. 휴대폰 바탕화면 앱 아이콘처럼 보이게 둔다.
class LibraryRoutineTile extends StatelessWidget {
  const LibraryRoutineTile({
    super.key,
    required this.routine,
    required this.isSentToday,
    required this.onTap,
    required this.onLongPress,
  });

  final Routine routine;

  /// 오늘 이룸이에게 이미 보냈는가 (오른쪽 아래 ✓)
  final bool isSentToday;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// 그림 칸 한 변 · 모서리 · ✓ 배지 한 변
  static const iconSize = 64.0;
  static const _iconRadius = 18.0;
  static const _badgeSize = 22.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final label = isSentToday
        ? '${routine.displayTitle}, ${context.l10n.routineLibrarySentBadge}'
        : routine.displayTitle;

    return Semantics(
      label: label,
      hint: context.l10n.routineLibraryTileHint,
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(_iconRadius.w),
                  child: SizedBox.square(
                    dimension: iconSize.w,
                    child: _Thumbnail(routine: routine),
                  ),
                ),
                if (isSentToday)
                  Positioned(
                    right: -space.xs.w / 2,
                    bottom: -space.xs.w / 2,
                    child: _SentBadge(size: _badgeSize.w),
                  ),
              ],
            ),
            SizedBox(height: space.xs.h),
            ContentLocale(
              language: routine.language,
              child: Text(
                routine.displayTitle,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: context.typo.caption.copyWith(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 첫 카드 그림. 카드가 없거나 그림이 없으면 제목 첫 글자
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.routine});

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
class _SentBadge extends StatelessWidget {
  const _SentBadge({required this.size});

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
