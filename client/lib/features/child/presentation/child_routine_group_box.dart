import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../shared/models/routine.dart';
import '../application/child_home_entries.dart';
import 'child_routine_tile.dart';

/// 묶음 상자 (#808, 시안 B안): 흰 상자 안에 묶음 이름 + 진행 `2 / 4` + 일과 줄을 항상 펼쳐 보인다
///
/// 안의 줄은 낱개 한 줄([ChildRoutineTile])과 같다. 묶음을 모두 끝내면 머리가 민트로 바뀌어 한 번 더 알려 준다.
class ChildRoutineGroupBox extends StatelessWidget {
  const ChildRoutineGroupBox({
    super.key,
    required this.entry,
    required this.progressOf,
  });

  final ChildGroupEntry entry;

  /// 일과 하나의 진행률(0.0~1.0)
  final double Function(Routine routine) progressOf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final total = entry.routines.length;
    final doneCount = entry.routines
        .where((routine) => progressOf(routine) >= 1.0)
        .length;
    final isAllDone = doneCount == total;
    final progressText = context.l10n.childHomeGroupProgress(doneCount, total);

    return Semantics(
      container: true,
      label: isAllDone
          ? '${entry.groupName}, ${context.l10n.childHomeGroupAllDone}'
          : '${entry.groupName}, $progressText',
      child: Container(
        padding: EdgeInsets.all(space.sm),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 머리: 이름 + 진행 (다 하면 민트 알약 + 안내)
            Padding(
              padding: EdgeInsets.fromLTRB(
                space.xs,
                space.xs,
                space.xs,
                space.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.groupName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typo.childDetailTitle.copyWith(
                        color: colors.chipLabel,
                      ),
                    ),
                  ),
                  SizedBox(width: space.xs),
                  _ProgressPill(
                    text: isAllDone
                        ? context.l10n.childHomeGroupAllDone
                        : progressText,
                    isAllDone: isAllDone,
                  ),
                ],
              ),
            ),
            for (final (index, routine) in entry.routines.indexed) ...[
              if (index > 0) SizedBox(height: space.sm),
              ChildRoutineTile(routine: routine, progress: progressOf(routine)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 묶음 진행 알약 (`2 / 4`, 다 하면 민트)
class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.text, required this.isAllDone});

  final String text;
  final bool isAllDone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: space.sm,
        vertical: space.xs / 2,
      ),
      decoration: BoxDecoration(
        color: isAllDone ? colors.childTileDone : colors.routineTileBg,
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
      child: Text(
        text,
        style: context.typo.caption.copyWith(
          color: isAllDone ? colors.chipLabel : colors.routineTileLabel,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
