import 'package:flutter/foundation.dart';

/// 크레딧 종류 3개: 주기 지급(주간·월간), 보너스(선물·광고·이벤트), 구매
enum CreditKind {
  periodic('PERIODIC'),
  bonus('BONUS'),
  purchased('PURCHASED');

  const CreditKind(this.wire);

  final String wire;

  /// 모르는 값이면 null (그 줄은 안 그림)
  static CreditKind? fromWire(Object? raw) {
    for (final kind in values) {
      if (kind.wire == raw) return kind;
    }
    return null;
  }
}

/// 종류별 한 줄 — 서버 `breakdown[]`
@immutable
class CreditBreakdownLine {
  const CreditBreakdownLine({
    required this.kind,
    required this.remaining,
    this.granted = 0,
    this.used = 0,
    this.expiresAt,
  });

  final CreditKind kind;
  final int remaining;
  final int granted;
  final int used;

  /// 끝나는 때 (구매는 null = 기간 제한 없음)
  final DateTime? expiresAt;

  /// 모양이 다르면 null (그 줄만 빠짐)
  static CreditBreakdownLine? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final kind = CreditKind.fromWire(raw['kind']);
    final remaining = raw['remaining'];
    if (kind == null || remaining is! num) return null;
    final granted = raw['granted'];
    final used = raw['used'];
    return CreditBreakdownLine(
      kind: kind,
      remaining: remaining.toInt(),
      granted: granted is num ? granted.toInt() : 0,
      used: used is num ? used.toInt() : 0,
      expiresAt: DateTime.tryParse(raw['expiresAt']?.toString() ?? '')?.toLocal(),
    );
  }
}
