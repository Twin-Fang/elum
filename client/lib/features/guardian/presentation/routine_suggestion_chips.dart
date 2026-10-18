import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../domain/routine_suggestion.dart';
import '../application/routine_providers.dart';

/// 추천 문구 칩 — Figma 2·2·1 배치.
///
/// `Wrap`으로 두면 글자 길이에 따라 줄이 밀린다. Figma 구조를 그대로 만든다.
///
/// 목록은 서버에서 오고 **개수가 고정이 아니다.** 2개씩 채우고 남는 하나는
/// 마지막 줄에 혼자 둔다(Figma 5개 = 2·2·1). 홀수·짝수 모두 대응된다.
class RoutineSuggestionChips extends ConsumerWidget {
  const RoutineSuggestionChips({super.key, required this.onTap});

  final ValueChanged<RoutineSuggestion> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref
        .watch(routineSuggestionsProvider)
        .maybeWhen(
          data: (list) => list,
          // 로딩·실패 중에는 칩을 감춘다. 입력창은 그대로 쓸 수 있으므로
          // 흐름이 막히지 않는다.
          orElse: () => const <RoutineSuggestion>[],
        );

    if (items.isEmpty) return const SizedBox.shrink();

    // 본문과 같은 좌우 여백 24. 글꼴 2.0 에서 두 칩이 한 줄을 다 차지해
    // 화면 끝에 붙었다. 글꼴 1.0 에서는 칩이 좁아 가운데 그대로라 시안 자리와 같다.
    //
    // 두 칩씩 묶는 것은 그대로 두되 **둘이 한 줄에 안 들어가면 한 줄에 하나씩** 둔다
    // (Wrap). 한 줄에 억지로 둘을 두면 칩이 좁아져 `병원 방 / 문 준비`처럼 낱말
    // 가운데서 꺾였다. 들어가면 Row 때와 같은 자리다.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.space.screenH.w),
      child: Column(
        children: [
          for (var row = 0; row < items.length; row += 2) ...[
            if (row > 0) SizedBox(height: context.space.xs),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6.w,
              runSpacing: context.space.xs,
              children: [
                for (final s in items.skip(row).take(2))
                  RoutineSuggestionChip(suggestion: s, onTap: onTap),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class RoutineSuggestionChip extends StatelessWidget {
  const RoutineSuggestionChip({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  final RoutineSuggestion suggestion;
  final ValueChanged<RoutineSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AppPressable(
      onTap: () => onTap(suggestion),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(space.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.standard,
            // Figma padding 10×16
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: context.colors.glassChip,
              borderRadius: BorderRadius.circular(space.cardRadius),
            ),
            child: Text(
              suggestion.label,
              style: context.typo.chipLabel.copyWith(
                color: context.colors.chipLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
