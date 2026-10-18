import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import 'grey_tile_shell.dart';

/// Figma 빈 상태 (217:2655 — 361×68, #EEE9E6) — `아직 만든 일과가 없어요`
///
/// 개편 시안에서 **캐릭터 배지가 빠졌다.** 일과 카드와 같은 상자에 같은 자리에서
/// 글이 시작해야 "여기가 일과가 들어올 자리"로 읽힌다 — 그림이 붙으면 다른
/// 종류의 알림처럼 보인다.
class EmptyRoutines extends StatelessWidget {
  const EmptyRoutines({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;

    return GreyTileShell(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.todayRoutineEmptyTitle,
            style: typo.routineEmptyTitle.copyWith(
              color: colors.routineTileLabel,
            ),
          ),
          SizedBox(height: _emptyLineGap.h),
          Text(
            context.l10n.todayRoutineEmptyHint,
            style: typo.routineTileMeta.copyWith(
              color: colors.routineEmptyHint,
            ),
          ),
        ],
      ),
    );
  }
}

/// 빈 상태 두 줄 사이 (일과 카드의 제목↔보상 간격과 같다)
const _emptyLineGap = 8.0;
