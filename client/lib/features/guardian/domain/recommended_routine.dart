import 'package:flutter/material.dart';

/// 추천 일과 — 보호자_홈 상단의 가로 스크롤 타일.
///
/// **지금은 하드코딩이다.** 나중에 AI가 동적으로 생성할 자리이며, 그때도
/// 색·이모지가 항목에 딸려 오므로 구조는 그대로 쓸 수 있다. (이슈 #19)
///
/// 색을 [AppColors] 토큰으로 빼지 않는 이유: 이 4쌍은 추천 항목에 딸린
/// 데이터지 전역 의미가 없다. 토큰을 8개 늘리면 AppColors만 비대해진다.
///
/// 이모지는 Figma 원본이 `type: TEXT` / `fontFamily: Pretendard`다.
/// 아이콘 컴포넌트가 아니라 다운로드할 에셋 자체가 없어 텍스트로 쓴다.
enum RecommendedRoutine {
  rainyCommute(
    label: '비 오는 날\n등교',
    emoji: '☔️',
    tile: Color(0xFFCEDBEF),
    circle: Color(0xFFA0B7DB),
  ),
  hospitalVisit(
    label: '병원 방문\n준비',
    emoji: '🏥',
    tile: Color(0xFFCEEFEB),
    circle: Color(0xFFADE2DC),
  ),
  fieldTrip(
    label: '체험학습\n준비',
    emoji: '🍱️',
    tile: Color(0xFFF5E9AE),
    circle: Color(0xFFE0D185),
  ),
  newPlace(
    label: '새로운 장소\n방문',
    emoji: '🚗',
    tile: Color(0xFFFCCAF3),
    circle: Color(0xFFF4B0E7),
  );

  const RecommendedRoutine({
    required this.label,
    required this.emoji,
    required this.tile,
    required this.circle,
  });

  /// 타일 문구. 줄바꿈 위치는 Figma가 정한 대로다.
  final String label;

  final String emoji;

  /// 타일 배경 (86×105, r20)
  final Color tile;

  /// 이모지를 감싸는 원 (39×39)
  final Color circle;

  /// 탭했을 때 일과 입력 화면에 미리 채울 문구.
  /// 줄바꿈은 타일 표시용이므로 한 줄로 편다.
  String get prefillText => label.replaceAll('\n', ' ');
}
