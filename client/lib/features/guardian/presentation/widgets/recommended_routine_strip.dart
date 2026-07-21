import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/recommended_routine.dart';

/// 추천 일과 가로 스크롤.
///
/// Figma 좌표가 `x=16, 106, 196, 286`(간격 90 = 타일 86 + 여백 4)이고 4번째 타일
/// 우측 끝이 372로 콘텐츠 영역 368을 넘어간다. **이 넘침이 스와이프 어포던스다** —
/// 잘린 타일이 보여야 "더 있다"가 전달되므로 의도적으로 살린다. (이슈 #19)
class RecommendedRoutineStrip extends StatelessWidget {
  const RecommendedRoutineStrip({super.key, required this.onTap});

  final ValueChanged<RecommendedRoutine> onTap;

  /// Figma 타일 높이
  static const tileHeight = 105.0;

  /// Figma 타일 폭
  static const tileWidth = 86.0;

  /// 타일 사이 여백 (좌표 간격 90 - 타일 폭 86)
  static const _gap = 4.0;

  /// 첫 타일의 x=16. 화면 가장자리에 가깝게 붙여야 잘린 느낌이 산다.
  static const _edgePadding = 16.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _edgePadding),
        itemCount: RecommendedRoutine.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final routine = RecommendedRoutine.values[index];
          return _RoutineTile(
            routine: routine,
            onTap: () => onTap(routine),
          );
        },
      ),
    );
  }
}

/// 추천 일과 타일 한 장 (86×105, r20).
class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.routine, required this.onTap});

  final RecommendedRoutine routine;
  final VoidCallback onTap;

  /// 이모지를 감싸는 원 (Figma 39×39)
  static const _circleSize = 39.0;

  /// 이모지 글자 크기 (Figma 24). 앱 폰트가 아니라 시스템 이모지라
  /// AppTypography 토큰이 아닌 여기 상수로 둔다.
  static const _emojiSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: RecommendedRoutineStrip.tileWidth,
        height: RecommendedRoutineStrip.tileHeight,
        decoration: BoxDecoration(
          color: routine.tile,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _circleSize,
              height: _circleSize,
              decoration: BoxDecoration(
                color: routine.circle,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              // Figma 원본이 텍스트 이모지다(fontFamily: Pretendard).
              // 아이콘 컴포넌트가 아니라 다운로드할 에셋 자체가 없다.
              // 시스템 이모지 폰트로 렌더링되므로 앱 폰트 토큰을 태우지 않는다.
              child: Text(routine.emoji, style: const TextStyle(fontSize: _emojiSize)),
            ),
            SizedBox(height: space.xs),
            Text(
              routine.label,
              textAlign: TextAlign.center,
              style: context.typo.tileLabel.copyWith(
                color: context.colors.chipLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
