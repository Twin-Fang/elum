import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 지난 일과가 0건일 때. 오늘 빈 상태와 달리 **권하지 않는다** —
/// 지난 일과는 시간이 지나면 저절로 쌓이는 것이라 할 일이 없다.
class EmptyPastLabel extends StatelessWidget {
  const EmptyPastLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        context.l10n.todayRoutinePastEmpty,
        style: context.typo.routineEmptyPast.copyWith(
          color: context.colors.routineTileLabel,
        ),
      ),
    );
  }
}
