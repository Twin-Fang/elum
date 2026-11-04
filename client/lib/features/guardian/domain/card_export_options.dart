import 'package:flutter/foundation.dart';

/// 카드 내보내기 형태 3가지: 일과 한 장 · 오려 쓰는 카드 · 카드 한 장씩 (#1073)
enum CardExportFormat {
  /// A4 한 장에 일과의 카드 전부 (벽에 붙이는 시각 일과표)
  routineSheet,

  /// A4 에 카드 여러 장 + 자를 점선 (코팅·벨크로 보드용)
  cutCards,

  /// 카드마다 이미지 한 장 (사진 저장·카톡)
  cardImages,
}

/// 카드 디자인 테마. 기본만 Free, 나머지는 Pro (`entitlements.cardExportAllThemes`)
///
/// 그림 꾸밈이 필요한 테마(바다·우주 등)는 디자이너 에셋이 오면 값과 토큰을 함께 더한다.
enum CardDesignTheme {
  /// 앱 카드 그대로 (순서별 색 · 테두리)
  basic,

  /// 장식 없이 흰 바탕 + 굵은 테두리 (집중이 어려운 이룸이용)
  simple,

  /// 흰 바탕 + 얇은 회색 테두리, 그림만 컬러 (잉크 절약)
  inkSaver,

  /// 그림까지 흑백 + 진한 선 (흑백 프린터 · 색칠 놀이). 번들 픽토그램은 변형하지 않음
  monochrome,

  /// 그림을 줄이고 글자를 크게 (글을 읽기 시작한 이룸이)
  largeText;

  /// Pro 만 고를 수 있는가
  bool get isProOnly => this != CardDesignTheme.basic;
}

/// 오려 쓰는 카드 한 쪽에 들어가는 장수 (열 × 줄)
enum CutCardsPerPage {
  four(columns: 2, rows: 2),
  six(columns: 2, rows: 3),
  eight(columns: 2, rows: 4);

  const CutCardsPerPage({required this.columns, required this.rows});

  final int columns;
  final int rows;

  int get count => columns * rows;
}

/// 내보내기 설정 한 벌. 화면이 바꾸고 지면 위젯이 그대로 읽는다
@immutable
class CardExportOptions {
  const CardExportOptions({
    this.format = CardExportFormat.routineSheet,
    this.theme = CardDesignTheme.basic,
    this.cutCardsPerPage = CutCardsPerPage.six,
    this.shouldIncludeText = true,
    this.excludedCardIds = const {},
  });

  final CardExportFormat format;
  final CardDesignTheme theme;
  final CutCardsPerPage cutCardsPerPage;

  /// 카드 문장을 넣는가 (그림만 쓰는 보호자는 끔)
  final bool shouldIncludeText;

  /// 카드 한 장씩에서 뺀 카드 id. 처음엔 비어 있음(전부 선택)
  final Set<String> excludedCardIds;

  CardExportOptions copyWith({
    CardExportFormat? format,
    CardDesignTheme? theme,
    CutCardsPerPage? cutCardsPerPage,
    bool? shouldIncludeText,
    Set<String>? excludedCardIds,
  }) => CardExportOptions(
    format: format ?? this.format,
    theme: theme ?? this.theme,
    cutCardsPerPage: cutCardsPerPage ?? this.cutCardsPerPage,
    shouldIncludeText: shouldIncludeText ?? this.shouldIncludeText,
    excludedCardIds: excludedCardIds ?? this.excludedCardIds,
  );
}

/// 일과 한 장의 열 수: 1~4장 2열, 5~9장 3열, 10장 2열×5줄 (한 장에 다 들어가게)
int routineSheetColumnsFor(int cardCount) {
  if (cardCount <= 4) return 2;
  if (cardCount >= 10) return 2;
  return 3;
}

/// 목록 > 쪽 묶음 (마지막 쪽은 덜 찰 수 있음). [perPage] 가 0 이하면 한 쪽
List<List<T>> chunkIntoPages<T>(List<T> items, int perPage) {
  if (perPage <= 0 || items.isEmpty) return [items];
  return [
    for (var start = 0; start < items.length; start += perPage)
      items.sublist(start, (start + perPage).clamp(0, items.length)),
  ];
}
