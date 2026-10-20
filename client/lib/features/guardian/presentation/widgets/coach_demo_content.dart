import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 코치마크 시범 안에 그려지는 내용물: 시트 버튼·메뉴 줄·만들기 선택지·토스트·묶음 모양.
/// 문구는 실제 화면과 같은 ARB 키를 쓴다 (따로 적으면 어긋난다).

/// 상세 시트 아래 버튼 둘 (실제 `_LibraryActions` 와 같은 문구·색·2:3 비율)
class CoachDemoSheetButtons extends StatelessWidget {
  const CoachDemoSheetButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final shape = BorderRadius.circular(18.r);
    Widget button(String label, Color background, Color foreground) =>
        Container(
          height: 56.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: background, borderRadius: shape),
          child: Text(
            label,
            style: typo.sheetActionLabel.copyWith(color: foreground),
          ),
        );
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: button(
            context.l10n.routineLibraryEditCards,
            colors.buttonNeutral,
            colors.buttonNeutralText,
          ),
        ),
        SizedBox(width: context.space.xs.w),
        Expanded(
          flex: 3,
          child: button(
            context.l10n.routineLibrarySendToday,
            colors.textPrimary,
            colors.surface,
          ),
        ),
      ],
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
  const CoachDemoGroupPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget cell({required bool isFilled}) => Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isFilled ? colors.checkDone : colors.buttonNeutral,
          borderRadius: BorderRadius.circular(6.r),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          children: [
            Expanded(
              child: Row(
                spacing: 4.w,
                children: [cell(isFilled: true), cell(isFilled: true)],
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
