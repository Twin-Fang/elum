import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../application/routine_notifier.dart';

/// 카드 확인 머리 아래 `AI 그림 N장 · M크레딧 사용 · K 남음` (#407 스펙 §5).
///
/// 방금 만든 일과가 얼마를 썼는지 그 자리에서 보여준다 — 설정까지 가야 알면 그림이
/// 많이 붙어 크레딧이 한 번에 준 것을 모른 채 다음 일과를 시작한다.
///
/// 생성 응답에 `credit` 이 없으면(크레딧 꺼짐·이미 만든 일과를 연 경우) **아무것도
/// 그리지 않는다** — 크기 0 이라 머리 배치는 그대로다.
///
/// ⚠️ 시안 밖 요소다 — 디자이너 협의 대상.
class CreditUsageLine extends ConsumerWidget {
  const CreditUsageLine({super.key});

  static const _gapAbove = 6.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(routineFlowProvider.select((s) => s.creditUsage));
    if (usage == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: _gapAbove.h),
      child: Text(
        'AI 그림 ${usage.imageCount}장 · ${usage.charged}크레딧 사용 · '
        '${usage.balanceAfter} 남음',
        textAlign: TextAlign.center,
        style: context.typo.creditCaption.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}
