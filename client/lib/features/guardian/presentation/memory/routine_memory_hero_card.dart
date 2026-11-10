import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../domain/routine_memory.dart';

/// 목록 탭 3개: 적용 중 · 관찰 중 · 수정 기록
enum RoutineMemoryTab { applied, watching, edits }

/// AI 메모리 위 카드: (Free 미리 보기만) PRO 배지 > `{이룸이} AI 메모리` > 설명 > 숫자 3칸 (누르면 아래 목록이 바뀜, 고른 칸에 테두리)
///
/// 오른쪽 위 그림 자리는 글 영역에서 비워 둠 (제목 글을 가리지 않게)
class RoutineMemoryHeroCard extends StatelessWidget {
  const RoutineMemoryHeroCard({
    super.key,
    required this.elumiName,
    required this.memory,
    required this.selectedTab,
    required this.onTabSelected,
    this.isProBadgeShown = false,
  });

  final String elumiName;
  final RoutineMemory memory;
  final RoutineMemoryTab selectedTab;
  final ValueChanged<RoutineMemoryTab> onTabSelected;
  final bool isProBadgeShown;

  static const _padding = 20.0;
  static const _heroSize = 110.0;
  static const _heroTextGap = 12.0;
  static const _statGap = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final l10n = context.l10n;
    final stats = [
      (RoutineMemoryTab.applied, memory.appliedCount, l10n.memoryStatApplied),
      (RoutineMemoryTab.watching, memory.watchingRules.length, l10n.memoryStatWatching),
      (RoutineMemoryTab.edits, memory.edits.length, l10n.memoryStatEdits),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.routineMemoryHeroStart, colors.routineMemoryHeroEnd],
        ),
        borderRadius: BorderRadius.circular(space.cardRadius.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(_padding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                // 글은 그림 자리만큼 오른쪽을 비움
                Padding(
                  padding: EdgeInsets.only(right: (_heroSize + _heroTextGap).w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isProBadgeShown) ...[const ProBadge(), SizedBox(height: space.xs.h)],
                      Text(l10n.memoryHeroTitle(elumiName), style: context.typo.cardTitle.copyWith(color: colors.textPrimary, height: 1.3)),
                      SizedBox(height: space.xs.h),
                      Text(l10n.memoryHeroBody, style: context.typo.creditBody.copyWith(color: colors.textSecondary)),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Image.asset(AppAssets.routineMemoryHero, width: _heroSize.w, excludeFromSemantics: true),
                ),
              ],
            ),
            SizedBox(height: space.md.h),
            Row(
              children: [
                for (final (index, stat) in stats.indexed) ...[
                  if (index > 0) SizedBox(width: _statGap.w),
                  Expanded(child: _StatBox(tab: stat.$1, count: stat.$2, label: stat.$3, isSelected: stat.$1 == selectedTab, onTap: onTabSelected)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.tab, required this.count, required this.label, required this.isSelected, required this.onTap});

  final RoutineMemoryTab tab;
  final int count;
  final String label;
  final bool isSelected;
  final ValueChanged<RoutineMemoryTab> onTap;

  static const _borderWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label $count',
      excludeSemantics: true,
      child: AppPressable(
        onTap: () => onTap(tab),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(space.cardRadius.r),
            border: Border.all(color: isSelected ? colors.textPrimary : Colors.transparent, width: _borderWidth.w),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: space.sm.h, horizontal: space.xs.w),
            child: Column(
              children: [
                Text('$count', style: context.typo.subtitle.copyWith(color: colors.textPrimary)),
                SizedBox(height: space.xs.h / 2),
                Text(label, textAlign: TextAlign.center, style: context.typo.creditCaption.copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
