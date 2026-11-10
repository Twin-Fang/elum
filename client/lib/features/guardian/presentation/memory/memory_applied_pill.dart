import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';

/// 새 일과 결과 화면 제목 아래 작은 알약 `AI 메모리 규칙 {N}개 적용됨 ›` (누르면 AI 메모리 화면)
class MemoryAppliedPill extends StatelessWidget {
  const MemoryAppliedPill({super.key, required this.count});

  final int count;

  static const _padH = 12.0;
  static const _padV = 4.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: AppPressable(
        onTap: () => context.push(Routes.guardianRoutineMemory),
        child: DecoratedBox(
          decoration: BoxDecoration(color: colors.routineMemoryHeroStart, borderRadius: BorderRadius.circular(context.space.pillRadius.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: _padH.w, vertical: _padV.h),
            child: Text('${context.l10n.memoryAppliedPill(count)} ›', style: context.typo.creditCaption.copyWith(color: colors.textPrimary)),
          ),
        ),
      ),
    );
  }
}
