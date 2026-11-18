import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 잠금화면 카드 종류: 보호자 진행 카드 · 이룸이 지금 할 카드 (네이티브 mode 값과 같은 이름)
enum LockScreenMode {
  guardian('guardian'),
  elumi('elumi');

  const LockScreenMode(this.wireName);

  final String wireName;

  static LockScreenMode fromWireName(Object? wireName) => values.firstWhere(
    (mode) => mode.wireName == wireName,
    orElse: () => LockScreenMode.guardian,
  );
}

/// 위젯 「오늘 일과 목록」 한 줄: 일과 id · 제목 · 끝낸 카드 수 / 전체 카드 수
@immutable
class LockScreenRoutineRow {
  const LockScreenRoutineRow({
    required this.id,
    required this.title,
    required this.doneCards,
    required this.totalCards,
  });

  final String id;
  final String title;
  final int doneCards;
  final int totalCards;

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'doneCards': doneCards, 'totalCards': totalCards};

  static LockScreenRoutineRow? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    return LockScreenRoutineRow(
      id: id,
      title: _stringOrEmpty(json['title']),
      doneCards: _intOrZero(json['doneCards']),
      totalCards: _intOrZero(json['totalCards']),
    );
  }
}

/// 위젯이 체크한 뒤 앱 없이 보여 줄 다음 카드 한 장 (#1465 2단계)
@immutable
class LockScreenUpcomingCard {
  const LockScreenUpcomingCard({
    required this.cardId,
    required this.cardText,
    this.imageFilePath,
    this.pictogramId,
    this.exampleImageId,
  });

  final String cardId;
  final String cardText;
  final String? imageFilePath;
  final String? pictogramId;
  final String? exampleImageId;

  LockScreenUpcomingCard copyWithImageFilePath(String? path) => LockScreenUpcomingCard(
    cardId: cardId,
    cardText: cardText,
    imageFilePath: path,
    pictogramId: pictogramId,
    exampleImageId: exampleImageId,
  );

  Map<String, Object?> toJson() => {
    'cardId': cardId,
    'cardText': cardText,
    'imageFilePath': imageFilePath,
    'pictogramId': pictogramId,
    'exampleImageId': exampleImageId,
  };

  static LockScreenUpcomingCard? fromJson(Object? json) {
    if (json is! Map) return null;
    final cardId = json['cardId'];
    if (cardId is! String || cardId.isEmpty) return null;
    return LockScreenUpcomingCard(
      cardId: cardId,
      cardText: _stringOrEmpty(json['cardText']),
      imageFilePath: _stringOrNull(json['imageFilePath']),
      pictogramId: _stringOrNull(json['pictogramId']),
      exampleImageId: _stringOrNull(json['exampleImageId']),
    );
  }
}

/// 이룸이 지금 할 카드 한 장: 일과 id·제목, 카드 글, 그림 (기기 파일 > 번들 그림 > 빈 칸)
@immutable
class LockScreenElumiCard {
  const LockScreenElumiCard({
    required this.routineId,
    required this.cardId,
    required this.routineTitle,
    required this.cardText,
    required this.contentLanguage,
    this.imageFilePath,
    this.pictogramId,
    this.exampleImageId,
    this.remainingCount = 1,
    this.upcomingCards = const [],
  });

  final String routineId;

  /// 카드 id (그림 파일을 찾을 때 씀)
  final String cardId;
  final String routineTitle;
  final String cardText;

  /// 카드 글 언어 (일과 언어, `ko` `en` …)
  final String contentLanguage;

  /// 기기에 받아 둔 카드 그림 파일 (없으면 null, 잠금화면은 네트워크를 쓰지 않음)
  final String? imageFilePath;
  final String? pictogramId;
  final String? exampleImageId;

  /// 이 일과에서 남은 카드 수 (지금 카드 포함) · 위젯 체크 뒤 보여 줄 다음 카드 (최대 [maximumUpcomingCards]장)
  final int remainingCount;
  final List<LockScreenUpcomingCard> upcomingCards;

  // 위젯이 앱 없이 넘겨 볼 다음 카드 수 (설계 2026-11-18-widget-card-check-design.md)
  static const maximumUpcomingCards = 2;

  LockScreenElumiCard copyWithUpcomingCards(List<LockScreenUpcomingCard> cards) => LockScreenElumiCard(
    routineId: routineId,
    cardId: cardId,
    routineTitle: routineTitle,
    cardText: cardText,
    contentLanguage: contentLanguage,
    imageFilePath: imageFilePath,
    pictogramId: pictogramId,
    exampleImageId: exampleImageId,
    remainingCount: remainingCount,
    upcomingCards: cards,
  );

  LockScreenElumiCard copyWithImageFilePath(String? path) => LockScreenElumiCard(
    routineId: routineId,
    cardId: cardId,
    routineTitle: routineTitle,
    cardText: cardText,
    contentLanguage: contentLanguage,
    imageFilePath: path,
    pictogramId: pictogramId,
    exampleImageId: exampleImageId,
    remainingCount: remainingCount,
    upcomingCards: upcomingCards,
  );

  Map<String, Object?> toJson() => {
    'routineId': routineId,
    'cardId': cardId,
    'routineTitle': routineTitle,
    'cardText': cardText,
    'contentLanguage': contentLanguage,
    'imageFilePath': imageFilePath,
    'pictogramId': pictogramId,
    'exampleImageId': exampleImageId,
    'remainingCount': remainingCount,
    'upcomingCards': [for (final card in upcomingCards) card.toJson()],
  };

  static LockScreenElumiCard? fromJson(Object? json) {
    if (json is! Map) return null;
    final routineId = json['routineId'];
    if (routineId is! String || routineId.isEmpty) return null;
    return LockScreenElumiCard(
      routineId: routineId,
      cardId: _stringOrEmpty(json['cardId']),
      routineTitle: _stringOrEmpty(json['routineTitle']),
      cardText: _stringOrEmpty(json['cardText']),
      contentLanguage: _stringOrEmpty(json['contentLanguage']),
      imageFilePath: _stringOrNull(json['imageFilePath']),
      pictogramId: _stringOrNull(json['pictogramId']),
      exampleImageId: _stringOrNull(json['exampleImageId']),
      remainingCount: json['remainingCount'] is int ? json['remainingCount'] as int : 1,
      upcomingCards: [
        if (json['upcomingCards'] case final List cards)
          for (final card in cards) ?LockScreenUpcomingCard.fromJson(card),
      ],
    );
  }
}

/// 오늘 일과 요약: 앱이 홈 목록을 받을 때마다 네이티브에 저장 > 잠금화면·알림·iOS 위젯이 네트워크 없이 읽음
/// 담는 것 6개: 날짜, 끝낸 수/전체 수, 다음 일과 제목, 이룸이 지금 할 카드, 이룸이 카드 띄울 시간대, 위젯용 이름·연속·별(#1465)
/// 원문 입력·개인정보 없음 (일과 제목·카드 글만)
@immutable
class LockScreenSnapshot {
  const LockScreenSnapshot({
    required this.mode,
    required this.dateKey,
    required this.doneCount,
    required this.totalCount,
    this.nextRoutineTitle,
    this.elumiCard,
    this.activeWindows = const [],
    this.elumiName,
    this.streakDays = 0,
    this.starCount = 0,
    this.routines = const [],
  });

  final LockScreenMode mode;

  /// 요약 날짜 (`yyyy-MM-dd`, 네이티브 LockScreenPreferences.today 와 같은 모양)
  final String dateKey;
  final int doneCount;
  final int totalCount;
  final String? nextRoutineTitle;
  final LockScreenElumiCard? elumiCard;

  /// 이룸이 카드 띄울 시간대 (시작·끝)
  final List<({DateTime start, DateTime end})> activeWindows;

  /// 위젯 머리에 보일 이룸이 이름 (없으면 null)
  final String? elumiName;

  /// 이어서 일과를 마친 일수 · 모은 별 수 (위젯 「별과 연속」, 모르면 0)
  final int streakDays;
  final int starCount;

  /// 위젯 「오늘 일과 목록」 줄 (오늘 순서대로 최대 [maximumRoutineRows]개)
  final List<LockScreenRoutineRow> routines;

  // 목록 위젯 대 크기가 보여 주는 줄 수 (설계 2026-11-18-lumi-widgets-design.md)
  static const maximumRoutineRows = 4;

  bool get isAllDone => totalCount > 0 && doneCount >= totalCount;

  /// [now] 날짜의 요약인가 (어제 받아 둔 요약은 "앱을 열어 확인" 으로 대신함)
  bool isFreshOn(DateTime now) => dateKey == dateKeyOf(now);

  static String dateKeyOf(DateTime time) =>
      '${time.year.toString().padLeft(4, '0')}-'
      '${time.month.toString().padLeft(2, '0')}-'
      '${time.day.toString().padLeft(2, '0')}';

  LockScreenSnapshot copyWithElumiCard(LockScreenElumiCard? card) => _copyWith(elumiCard: card);

  /// 위젯용 이름·연속·별 채우기 (요약 빌더는 일과만 봄)
  LockScreenSnapshot copyWithWidgetExtras({
    required String? elumiName,
    required int streakDays,
    required int starCount,
  }) => _copyWith(elumiName: elumiName, streakDays: streakDays, starCount: starCount);

  LockScreenSnapshot _copyWith({
    LockScreenElumiCard? elumiCard,
    String? elumiName,
    int? streakDays,
    int? starCount,
  }) => LockScreenSnapshot(
    mode: mode,
    dateKey: dateKey,
    doneCount: doneCount,
    totalCount: totalCount,
    nextRoutineTitle: nextRoutineTitle,
    elumiCard: elumiCard ?? this.elumiCard,
    activeWindows: activeWindows,
    elumiName: elumiName ?? this.elumiName,
    streakDays: streakDays ?? this.streakDays,
    starCount: starCount ?? this.starCount,
    routines: routines,
  );

  String toJsonString() => jsonEncode({
    'mode': mode.wireName,
    'dateKey': dateKey,
    'doneCount': doneCount,
    'totalCount': totalCount,
    'nextRoutineTitle': nextRoutineTitle,
    'elumiCard': elumiCard?.toJson(),
    'activeWindows': [
      for (final window in activeWindows)
        [
          window.start.millisecondsSinceEpoch,
          window.end.millisecondsSinceEpoch,
        ],
    ],
    'elumiName': elumiName,
    'streakDays': streakDays,
    'starCount': starCount,
    'routines': [for (final routine in routines) routine.toJson()],
  });

  /// 깨졌거나 비었으면 null (잠금화면은 "앱을 열어 확인" 으로 대신함)
  static LockScreenSnapshot? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return null;
      final dateKey = decoded['dateKey'];
      if (dateKey is! String) return null;
      return LockScreenSnapshot(
        mode: LockScreenMode.fromWireName(decoded['mode']),
        dateKey: dateKey,
        doneCount: _intOrZero(decoded['doneCount']),
        totalCount: _intOrZero(decoded['totalCount']),
        nextRoutineTitle: _stringOrNull(decoded['nextRoutineTitle']),
        elumiCard: LockScreenElumiCard.fromJson(decoded['elumiCard']),
        activeWindows: _windowsOf(decoded['activeWindows']),
        elumiName: _stringOrNull(decoded['elumiName']),
        streakDays: _intOrZero(decoded['streakDays']),
        starCount: _intOrZero(decoded['starCount']),
        routines: [
          if (decoded['routines'] case final List rows)
            for (final row in rows) ?LockScreenRoutineRow.fromJson(row),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  static List<({DateTime start, DateTime end})> _windowsOf(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final window in raw)
        if (window is List &&
            window.length >= 2 &&
            window[0] is int &&
            window[1] is int)
          (
            start: DateTime.fromMillisecondsSinceEpoch(window[0] as int),
            end: DateTime.fromMillisecondsSinceEpoch(window[1] as int),
          ),
    ];
  }
}

int _intOrZero(Object? raw) => raw is int ? raw : 0;

String _stringOrEmpty(Object? raw) => raw is String ? raw : '';

String? _stringOrNull(Object? raw) =>
    raw is String && raw.trim().isNotEmpty ? raw : null;
