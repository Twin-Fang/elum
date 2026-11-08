import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// 카드 내보내기 형태 3가지: 일과 한 장 · 오려 쓰는 카드 · 카드 한 장씩 (#1073)
enum CardExportFormat {
  /// A4 한 장에 일과의 카드 전부 (벽에 붙이는 시각 일과표)
  routineSheet,

  /// A4 에 카드 여러 장 + 자를 점선 (코팅·벨크로 보드용)
  cutCards,

  /// 카드마다 이미지 한 장 (사진 저장·카톡)
  cardImages;

  /// 용지 방향 · 카드 크기를 고르는 형태인가 (카드 한 장씩은 카드 크기 그대로)
  bool get hasPaperLayout => this != CardExportFormat.cardImages;
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

/// 용지 방향 (A4 세로 595×842 · 가로 842×595)
enum PaperOrientation { portrait, landscape }

/// 오려 쓰는 카드 한 쪽에 넣는 장수. 열·줄은 용지 방향에 맞춰 [bestCardGridLayout] 이 정함
enum CardsPerPage {
  one(1),
  two(2),
  four(4),
  six(6),
  eight(8);

  const CardsPerPage(this.count);

  final int count;
}

/// 카드 크기: 칸에 맞춰 가장 크게 들어가는 크기 대비 비율 (작을수록 자를 여백이 넓음)
enum CardSize {
  fit(1),
  medium(0.85),
  small(0.7);

  const CardSize(this.scale);

  final double scale;
}

/// 인쇄 카드 가로:세로 = 앱 카드(333×410). 어떤 배치에서도 이 비율을 지키고 크기만 바뀜
const printCardAspectRatio = 333 / 410;

/// 인쇄 카드 그림 칸 가로:세로 (AI 그림 4:3)
const printCardPictureAspectRatio = 4 / 3;

/// 내보내기 설정 한 벌. 화면이 바꾸고 지면 위젯이 그대로 읽는다
@immutable
class CardExportOptions {
  const CardExportOptions({
    this.format = CardExportFormat.cardImages,
    this.theme = CardDesignTheme.basic,
    this.orientation = PaperOrientation.portrait,
    this.cardsPerPage = CardsPerPage.six,
    this.cardSize = CardSize.fit,
    this.shouldIncludeText = true,
    this.excludedCardIds = const {},
  });

  final CardExportFormat format;
  final CardDesignTheme theme;
  final PaperOrientation orientation;
  final CardsPerPage cardsPerPage;
  final CardSize cardSize;

  /// 카드 문장을 넣는가 (그림만 쓰는 보호자는 끔)
  final bool shouldIncludeText;

  /// 카드 한 장씩에서 뺀 카드 id. 처음엔 비어 있음(전부 선택)
  final Set<String> excludedCardIds;

  /// 형태·배치 권한(`cardExportAllLayouts`)이 있어야 하는 설정인가 (Free 는 카드 한 장씩만)
  bool get requiresAllLayouts => format != CardExportFormat.cardImages;

  /// 권한 밖 설정 > Free 가 쓸 수 있는 값으로 (Pro 가 끝난 뒤 남은 설정이 파일로 나가지 않게)
  CardExportOptions limitedTo({required bool canUseAllLayouts, required bool canUseAllThemes}) => copyWith(
    format: canUseAllLayouts ? format : CardExportFormat.cardImages,
    theme: canUseAllThemes ? theme : CardDesignTheme.basic,
  );

  CardExportOptions copyWith({
    CardExportFormat? format,
    CardDesignTheme? theme,
    PaperOrientation? orientation,
    CardsPerPage? cardsPerPage,
    CardSize? cardSize,
    bool? shouldIncludeText,
    Set<String>? excludedCardIds,
  }) => CardExportOptions(
    format: format ?? this.format,
    theme: theme ?? this.theme,
    orientation: orientation ?? this.orientation,
    cardsPerPage: cardsPerPage ?? this.cardsPerPage,
    cardSize: cardSize ?? this.cardSize,
    shouldIncludeText: shouldIncludeText ?? this.shouldIncludeText,
    excludedCardIds: excludedCardIds ?? this.excludedCardIds,
  );
}

/// 카드 격자 한 벌: 열 · 줄 · 카드 한 장 크기
typedef CardGridLayout = ({int columns, int rows, Size cardSize});

/// 카드 [cardCount] 장 > [area] 안에서 카드 비율을 지키며 가장 크게 들어가는 열 수
///
/// 열 1 ~ [cardCount] 를 모두 재 보고 카드 폭이 가장 큰 것 (같으면 열이 적은 쪽)
CardGridLayout bestCardGridLayout({
  required int cardCount,
  required Size area,
  required double gap,
  double aspectRatio = printCardAspectRatio,
}) {
  final count = cardCount < 1 ? 1 : cardCount;
  CardGridLayout? best;
  for (var columns = 1; columns <= count; columns++) {
    final rows = (count / columns).ceil();
    final cellWidth = (area.width - gap * (columns - 1)) / columns;
    final cellHeight = (area.height - gap * (rows - 1)) / rows;
    if (cellWidth <= 0 || cellHeight <= 0) continue;
    final cardWidth = cellWidth < cellHeight * aspectRatio ? cellWidth : cellHeight * aspectRatio;
    if (best == null || cardWidth > best.cardSize.width) {
      best = (columns: columns, rows: rows, cardSize: Size(cardWidth, cardWidth / aspectRatio));
    }
  }
  return best ?? (columns: 1, rows: count, cardSize: Size.zero);
}

/// 목록 > 쪽 묶음 (마지막 쪽은 덜 찰 수 있음). [perPage] 가 0 이하면 한 쪽
List<List<T>> chunkIntoPages<T>(List<T> items, int perPage) {
  if (perPage <= 0 || items.isEmpty) return [items];
  return [
    for (var start = 0; start < items.length; start += perPage)
      items.sublist(start, (start + perPage).clamp(0, items.length)),
  ];
}
