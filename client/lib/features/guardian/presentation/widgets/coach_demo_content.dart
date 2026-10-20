import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 코치마크 시범 안에 그려지는 내용물: 메뉴 줄·만들기 선택지·토스트·묶음 모양.
/// 문구는 실제 화면과 같은 ARB 키를 쓴다 (따로 적으면 어긋난다).

/// 칸 옆 메뉴 미리보기: 실제 길게 누르기 메뉴와 같은 폭 · 줄 높이 · 항목 5개 (지우기는 붉게)
class CoachDemoAnchoredMenu extends StatelessWidget {
  const CoachDemoAnchoredMenu({super.key});

  /// 실제 칸 옆 메뉴와 같은 폭 · 줄 높이
  static const width = 230.0;
  static const rowHeight = 46.0;

  /// 항목 5개: 오늘 보내기, 이름 바꾸기, 묶음에 넣기, 복사하기, 지우기
  static const rowCount = 5;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final rows = <(IconData, String, bool)>[
      (Icons.send_rounded, l10n.routineLibrarySendToday, false),
      (Icons.edit_rounded, l10n.routineLibraryMenuRename, false),
      (
        Icons.create_new_folder_outlined,
        l10n.routineGroupMenuAddToGroup,
        false,
      ),
      (Icons.content_copy_rounded, l10n.routineLibraryMenuCopy, false),
      (Icons.delete_outline_rounded, l10n.routineLibraryMenuRemove, true),
    ];
    return Container(
      width: width.w,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(context.space.md.r),
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.2),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (icon, label, isDanger) in rows)
            SizedBox(
              height: rowHeight.h,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.space.md.w),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typo.body.copyWith(
                          color: isDanger ? colors.danger : colors.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      icon,
                      size: 20.w,
                      color: isDanger ? colors.danger : colors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CoachDemoToast extends StatelessWidget {
  const CoachDemoToast({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
    decoration: BoxDecoration(
      color: context.colors.textPrimary,
      borderRadius: BorderRadius.circular(24.r),
    ),
    child: Text(
      text,
      style: context.typo.body.copyWith(color: context.colors.surface),
    ),
  );
}

class CoachDemoGhostTile extends StatelessWidget {
  const CoachDemoGhostTile({
    super.key,
    required this.color,
    required this.opacity,
    this.child,
  });

  final Color color;
  final double opacity;

  /// 칸 안에 그릴 내용 (예시 일과 그림). 없으면 빈 칸
  final Widget? child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: context.colors.textPrimary.withValues(alpha: 0.2),
            blurRadius: 10,
          ),
        ],
      ),
      child: child == null
          ? null
          : ClipRRect(borderRadius: BorderRadius.circular(16.r), child: child),
    ),
  );
}

/// 묶음 칸의 2×2 미리보기 모양 (일과 둘 + 빈 칸 둘)
class CoachDemoGroupPreview extends StatelessWidget {
  const CoachDemoGroupPreview({super.key, this.items = const []});

  /// 앞 두 칸에 그릴 일과 그림 (최대 2개). 없으면 색 칸
  final List<Widget> items;

  /// 칸 그림을 먼저 그리는 크기 (실제 묶음 칸과 같다)
  static const _itemRenderSize = 100.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget cell({required bool isFilled, Widget? child}) => Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.r),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isFilled ? colors.surface : colors.background,
          ),
          // 실제 묶음 칸처럼 큰 칸에 그린 뒤 줄인다 (그림 여백이 고정이라 작은 칸에 바로 그리면 흰 칸이 된다)
          child: child == null
              ? null
              : FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox.square(
                    dimension: _itemRenderSize,
                    child: child,
                  ),
                ),
        ),
      ),
    );
    Widget? itemAt(int index) => index < items.length ? items[index] : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        // 막 위에 떠 있으므로 실제 화면 바탕에 얹은 색으로 (반투명이면 어둡게 비친다)
        color: Color.alphaBlend(colors.folderFill, colors.background),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          children: [
            Expanded(
              child: Row(
                spacing: 4.w,
                children: [
                  cell(isFilled: true, child: itemAt(0)),
                  cell(isFilled: true, child: itemAt(1)),
                ],
              ),
            ),
            SizedBox(height: 4.w),
            Expanded(
              child: Row(
                spacing: 4.w,
                children: [cell(isFilled: false), cell(isFilled: false)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
