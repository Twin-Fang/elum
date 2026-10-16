import 'package:flutter/foundation.dart';

/// 사용 내역 한 줄의 종류 — 서버 `CreditHistoryKind`.
enum CreditHistoryKind {
  routineText('ROUTINE_TEXT'),
  cardImages('CARD_IMAGES'),
  cardImage('CARD_IMAGE'),
  imageRegenerate('IMAGE_REGENERATE'),
  weeklyGrant('WEEKLY_GRANT'),
  adReward('AD_REWARD'),
  adminBonus('ADMIN_BONUS'),
  otherGrant('OTHER_GRANT'),
  expired('EXPIRED'),
  adjusted('ADJUSTED');

  const CreditHistoryKind(this.wire);

  final String wire;

  /// 모르는 값은 null — 서버가 새 종류를 먼저 배포해도 줄은 증감 부호로 읽는다.
  static CreditHistoryKind? from(Object? raw) {
    for (final kind in values) {
      if (kind.wire == raw) return kind;
    }
    return null;
  }

  /// 일과·그림을 만들며 쓴 줄 — 일과 제목이 윗줄에 선다.
  bool get isUsage => switch (this) {
    routineText || cardImages || cardImage || imageRegenerate => true,
    _ => false,
  };
}

/// 사용 내역 한 줄 — 서버 `CreditHistoryResponse.Entry`.
@immutable
class CreditHistoryEntry {
  const CreditHistoryEntry({
    required this.id,
    required this.kind,
    required this.delta,
    required this.occurredAt,
    this.routineTitle,
    this.cardCount,
  });

  final String id;

  /// 앱이 모르는 종류면 null.
  final CreditHistoryKind? kind;

  /// 사용은 음수, 지급은 양수.
  final int delta;

  /// 기기 시간대로 바꾼 시각.
  final DateTime occurredAt;

  /// 일과가 지워졌거나 사용 줄이 아니면 null.
  final String? routineTitle;

  /// 카드 그림 수 (그림 줄만).
  final int? cardCount;

  /// 필수 값이 하나라도 틀리면 null — 틀린 숫자를 그리느니 줄을 뺀다.
  static CreditHistoryEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final delta = _asInt(raw['delta']);
    // 시간대가 붙은 값을 먼저 쓰고 기기 시간대로 바꾼다
    final occurredAt =
        DateTime.tryParse(raw['occurredAtOffset']?.toString() ?? '')?.toLocal() ??
        DateTime.tryParse(raw['occurredAt']?.toString() ?? '');
    if (id is! String || id.isEmpty || delta == null || occurredAt == null) {
      return null;
    }
    final title = raw['routineTitle'];
    return CreditHistoryEntry(
      id: id,
      kind: CreditHistoryKind.from(raw['kind']),
      delta: delta,
      occurredAt: occurredAt,
      routineTitle: title is String && title.trim().isNotEmpty ? title : null,
      cardCount: _asInt(raw['cardCount']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CreditHistoryEntry &&
      other.id == id &&
      other.kind == kind &&
      other.delta == delta &&
      other.occurredAt == occurredAt &&
      other.routineTitle == routineTitle &&
      other.cardCount == cardCount;

  @override
  int get hashCode =>
      Object.hash(id, kind, delta, occurredAt, routineTitle, cardCount);
}

/// 사용 내역 한 쪽 — 서버 `GET /api/credits/ledger`.
@immutable
class CreditHistoryPage {
  const CreditHistoryPage({
    required this.entries,
    required this.hasNext,
    required this.page,
  });

  final List<CreditHistoryEntry> entries;
  final bool hasNext;
  final int page;

  /// 겉 모양이 틀리면 [FormatException] — 빈 목록으로 읽으면 "사용한 적 없다"로 보인다.
  factory CreditHistoryPage.fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final hasNext = json['hasNext'];
    final page = _asInt(json['page']);
    if (rawEntries is! List || hasNext is! bool || page == null) {
      throw FormatException('사용 내역 응답 모양이 다르다', json);
    }
    return CreditHistoryPage(
      entries: [
        for (final raw in rawEntries) ?CreditHistoryEntry.tryParse(raw),
      ],
      hasNext: hasNext,
      page: page,
    );
  }
}

int? _asInt(Object? raw) => switch (raw) {
  final int v => v,
  final num v when v == v.roundToDouble() => v.toInt(),
  _ => null,
};

/// 같은 날(기기 시간대)의 줄 묶음 — 날짜 머리글 하나에 흰 카드 하나.
@immutable
class CreditHistoryDay {
  const CreditHistoryDay({required this.date, required this.entries});

  /// 자정으로 맞춘 날짜.
  final DateTime date;
  final List<CreditHistoryEntry> entries;
}

/// 최근 것부터 온 줄을 날짜별로 묶는다. 줄 순서와 날짜 순서는 그대로 둔다.
List<CreditHistoryDay> groupCreditHistoryByDay(
  List<CreditHistoryEntry> entries,
) {
  final days = <CreditHistoryDay>[];
  for (final entry in entries) {
    final at = entry.occurredAt;
    final date = DateTime(at.year, at.month, at.day);
    if (days.isNotEmpty && days.last.date == date) {
      days.last.entries.add(entry);
    } else {
      days.add(CreditHistoryDay(date: date, entries: [entry]));
    }
  }
  return days;
}
