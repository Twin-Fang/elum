import 'package:flutter/material.dart';

/// 행동 카드의 순서별 색.
///
/// Figma `카드확인`(262:5124)과 `보호자_홈_최근일과`(309:3739)가 카드마다 다른
/// 색을 쓴다. 순서로 배정되므로 카드 데이터가 색을 들고 있을 필요가 없다.
///
/// `AppColors` 토큰으로 빼지 않는 이유 — 이 5쌍은 "N번째 카드"라는 순서에
/// 딸린 값이지 전역 의미가 없다. 토큰을 10개 늘리면 AppColors만 비대해진다.
/// (홈 추천 타일과 같은 판단)
@immutable
class CardPalette {
  const CardPalette({required this.fill, required this.border});

  /// 카드 배경
  final Color fill;

  /// 카드 테두리 (2px). 번호 배지 색으로도 쓴다.
  final Color border;

  /// Figma 카드확인 화면의 카드 3종 + 홈 리스트 배지 5종에서 뽑았다.
  static const _all = [
    CardPalette(fill: Color(0xFFB5EAEC), border: Color(0xFF93DBCC)), // 민트
    CardPalette(fill: Color(0xFFCED8FF), border: Color(0xFF9CADF1)), // 파랑
    CardPalette(fill: Color(0xFFFFDAC7), border: Color(0xFFEB9B73)), // 복숭아
    CardPalette(fill: Color(0xFFFFF3C4), border: Color(0xFFF3C500)), // 노랑
    CardPalette(fill: Color(0xFFE8F5C8), border: Color(0xFFC7EB73)), // 연두
  ];

  /// [index]번째 카드의 색. 카드가 5장을 넘으면 처음부터 다시 돈다.
  ///
  /// 나머지 연산으로 감싸는 이유 — AI가 몇 장을 만들지 알 수 없다.
  /// 실측에서 9장이 온 적도 있어 범위를 벗어나면 화면이 죽는다.
  static CardPalette at(int index) => _all[index % _all.length];

  static int get length => _all.length;
}
