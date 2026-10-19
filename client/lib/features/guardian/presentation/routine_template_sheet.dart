import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_bottom_sheet.dart';
import '../domain/routine_template.dart';
import '../domain/routine_template_catalog.dart';

/// 예시 일과 시트 (#777): 카테고리 고르기 > 예시 고르기 > 고른 예시를 돌려준다
///
/// 시트는 입력칸을 직접 채우지 않는다 — 부르는 쪽(일과 만들기 화면)이 채운다.
class RoutineTemplateSheet extends StatefulWidget {
  const RoutineTemplateSheet({super.key});

  /// 시트 높이 비율 (일과 상세 시트와 같은 0.72)
  static const heightRatio = 0.72;

  static Future<RoutineTemplate?> show(BuildContext context) =>
      showElumSheet<RoutineTemplate>(
        context: context,
        builder: (_) => const RoutineTemplateSheet(),
      );

  static ValueKey<String> categoryKey(RoutineTemplateCategory category) =>
      ValueKey('routine.template.category.${category.name}');

  static ValueKey<String> templateKey(RoutineTemplate template) =>
      ValueKey('routine.template.${template.id}');

  @override
  State<RoutineTemplateSheet> createState() => _RoutineTemplateSheetState();
}

class _RoutineTemplateSheetState extends State<RoutineTemplateSheet> {
  var _category = RoutineTemplateCategory.values.first;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final l10n = context.l10n;
    final templates = routineTemplatesOf(_category);

    return ElumSheetSurface(
      height:
          MediaQuery.sizeOf(context).height * RoutineTemplateSheet.heightRatio,
      // 여백은 내용에 준다 (시트 면에 주면 손잡이까지 밀려 제목과 겹친다)
      child: Padding(
        padding: EdgeInsets.only(
          top: (ElumSheetSurface.defaultHandleTop + space.lg).h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 제목 · 설명
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.routineTemplateSheetTitle,
                    style: typo.sheetTitle.copyWith(color: colors.textPrimary),
                  ),
                  SizedBox(height: space.xs),
                  Text(
                    l10n.routineTemplateSheetBody,
                    style: typo.promptBody.copyWith(color: colors.promptMuted),
                  ),
                ],
              ),
            ),
            SizedBox(height: space.md),
            // 카테고리 줄 (가로 스크롤)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
              child: Row(
                children: [
                  for (final category in RoutineTemplateCategory.values) ...[
                    _CategoryChip(
                      key: RoutineTemplateSheet.categoryKey(category),
                      label: category.labelOf(l10n),
                      isSelected: category == _category,
                      onTap: () => setState(() => _category = category),
                    ),
                    SizedBox(width: 6.w),
                  ],
                ],
              ),
            ),
            SizedBox(height: space.sm),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
              child: Text(
                _category.hintOf(l10n),
                style: typo.promptBody.copyWith(color: colors.promptMuted),
              ),
            ),
            SizedBox(height: space.sm),
            // 예시 목록
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  space.screenH.w,
                  0,
                  space.screenH.w,
                  MediaQuery.paddingOf(context).bottom + space.md,
                ),
                itemCount: templates.length,
                separatorBuilder: (_, _) => SizedBox(height: space.xs),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return _TemplateRow(
                    key: RoutineTemplateSheet.templateKey(template),
                    template: template,
                    onTap: () => Navigator.of(context).pop(template),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 카테고리 칩: 고른 것은 진한 바탕
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: isSelected,
      button: true,
      child: AppPressable(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isSelected ? colors.textPrimary : colors.editChipBg,
            borderRadius: BorderRadius.circular(context.space.cardRadius),
          ),
          child: Text(
            label,
            style: context.typo.chipLabel.copyWith(
              color: isSelected ? colors.surface : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 예시 한 줄: 이모지 · 이름 · 처음이라면 추천 표시
class _TemplateRow extends StatelessWidget {
  const _TemplateRow({super.key, required this.template, required this.onTap});

  final RoutineTemplate template;
  final VoidCallback onTap;

  /// 줄 최소 높이 (글자가 커지면 늘어난다)
  static const minHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final l10n = context.l10n;

    return AppPressable(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight.h),
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: colors.editChipBg,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          children: [
            Text(template.icon, style: typo.sheetTitle),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    template.textOf(l10n),
                    style: typo.sheetStepTitle.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  if (template.isBeginnerFriendly) ...[
                    SizedBox(height: 2.h),
                    Text(
                      l10n.routineTemplateBeginnerBadge,
                      style: typo.chipLabel.copyWith(color: colors.promptMuted),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 24.w,
              color: colors.rewardEmptyLabel,
            ),
          ],
        ),
      ),
    );
  }
}
