import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../data/routine_repository.dart';
import '../../domain/routine_suggestion.dart';

/// 타일 한 장의 배경·원 색 한 쌍.
typedef _TileColors = ({Color tile, Color circle});

/// 추천 일과 가로 스크롤.
///
/// Figma 좌표가 `x=16, 106, 196, 286`(간격 90 = 타일 86 + 여백 4)이고 4번째 타일
/// 우측 끝이 372로 콘텐츠 영역 368을 넘어간다. **이 넘침이 스와이프 어포던스다** —
/// 잘린 타일이 보여야 "더 있다"가 전달되므로 의도적으로 살린다. (이슈 #19)
///
/// 목록은 서버 `GET /api/routines/suggestions`에서 온다. **개수를 고정하지 않는다** —
/// 서버가 몇 개를 주든 팔레트가 순환하므로 깨지지 않는다. (이슈 #36)
class RecommendedRoutineStrip extends ConsumerWidget {
  const RecommendedRoutineStrip({super.key, required this.onTap});

  final ValueChanged<RoutineSuggestion> onTap;

  /// Figma 타일 높이
  static const tileHeight = 105.0;

  /// Figma 타일 폭
  static const tileWidth = 86.0;

  /// 타일 사이 여백 (좌표 간격 90 - 타일 폭 86)
  static const _gap = 4.0;

  /// 첫 타일의 x=16. 화면 가장자리에 가깝게 붙여야 잘린 느낌이 산다.
  static const _edgePadding = 16.0;

  /// 로딩 중 보여줄 자리표시 개수. Figma 기본 노출량과 맞춘다.
  static const _skeletonCount = 4;

  /// 서버가 색을 주지 않아 화면이 인덱스로 배정한다. Figma `보호자_홈` 4색.
  ///
  /// 색을 서버 응답에 넣지 않는 이유 — 디자인 값을 백엔드가 알아야 하는 구조가
  /// 되면 관리 지점이 둘로 나뉜다. 순환이라 항목이 늘어도 대응된다.
  static const _palette = <_TileColors>[
    (tile: Color(0xFFCEDBEF), circle: Color(0xFFA0B7DB)), // 파랑
    (tile: Color(0xFFCEEFEB), circle: Color(0xFFADE2DC)), // 민트
    (tile: Color(0xFFF5E9AE), circle: Color(0xFFE0D185)), // 노랑
    (tile: Color(0xFFFCCAF3), circle: Color(0xFFF4B0E7)), // 핑크
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestions = ref.watch(routineSuggestionsProvider);

    // repository가 실패를 흡수해 fallback을 주므로 error 분기는 사실상 오지
    // 않는다. 그래도 provider 단계의 예외까지 막아 화면이 붉게 덮이지 않게 한다.
    final items = suggestions.maybeWhen(
      data: (list) => list,
      orElse: () => const <RoutineSuggestion>[],
    );

    return SizedBox(
      height: tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _edgePadding),
        // 로딩 중에는 자리만 잡아둔다. 높이가 0이 되면 아래 섹션이 튄다.
        itemCount: items.isEmpty ? _skeletonCount : items.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final colors = _palette[index % _palette.length];
          if (items.isEmpty) return _SkeletonTile(colors: colors);

          final suggestion = items[index];
          return _RoutineTile(
            suggestion: suggestion,
            colors: colors,
            onTap: () => onTap(suggestion),
          );
        },
      ),
    );
  }
}

/// 추천 일과 타일 한 장 (86×105, r20).
class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.suggestion,
    required this.colors,
    required this.onTap,
  });

  final RoutineSuggestion suggestion;
  final _TileColors colors;
  final VoidCallback onTap;

  /// 이모지를 감싸는 원 (Figma 39×39)
  static const _circleSize = 39.0;

  /// 이모지 글자 크기 (Figma 24). 앱 폰트가 아니라 시스템 이모지라
  /// AppTypography 토큰이 아닌 여기 상수로 둔다.
  static const _emojiSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: Container(
        width: RecommendedRoutineStrip.tileWidth,
        height: RecommendedRoutineStrip.tileHeight,
        padding: EdgeInsets.symmetric(horizontal: space.xs),
        decoration: BoxDecoration(
          color: colors.tile,
          borderRadius: BorderRadius.circular(space.cardRadius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _circleSize,
              height: _circleSize,
              decoration: BoxDecoration(
                color: colors.circle,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              // Figma 원본이 텍스트 이모지다(fontFamily: Pretendard).
              // 아이콘 컴포넌트가 아니라 다운로드할 에셋 자체가 없다.
              // 시스템 이모지 폰트로 렌더링되므로 앱 폰트 토큰을 태우지 않는다.
              child: Text(
                suggestion.icon,
                style: const TextStyle(fontSize: _emojiSize),
              ),
            ),
            SizedBox(height: space.xs),
            // 서버 문구는 길이가 제각각이다. 2줄까지만 보이고 넘치면 자른다 —
            // 타일 높이가 105로 고정이라 넘치면 오버플로가 난다.
            Text(
              suggestion.text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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

/// 로딩 자리표시. 빈 화면 대신 타일 모양을 미리 잡아둔다.
///
/// 로딩과 빈 상태를 시각적으로 구분한다 — 아무것도 없으면 "고장났나?"로 읽힌다.
class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile({required this.colors});

  final _TileColors colors;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return Container(
      width: RecommendedRoutineStrip.tileWidth,
      height: RecommendedRoutineStrip.tileHeight,
      decoration: BoxDecoration(
        // 실제 타일보다 옅게 — 아직 내용이 아니라는 신호다
        color: colors.tile.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(space.cardRadius),
      ),
    );
  }
}
