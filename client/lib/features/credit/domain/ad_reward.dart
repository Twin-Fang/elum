import 'package:flutter/foundation.dart';

/// 광고 보고 더 만들기를 보일지 — 서버 `GET /api/credits/ad-rewards/offer` (#463).
///
/// **모르는 값을 채우지 않는다.** 필드가 빠지면 [FormatException] 을 던지고, 호출한 쪽이
/// 버튼을 숨긴다. 꺼짐으로 읽고 보이는 쪽이 잘못 보여 주는 쪽보다 안전하다.
@immutable
class AdRewardOffer {
  const AdRewardOffer({
    required this.enabled,
    required this.creditsPerView,
    required this.remainingToday,
  });

  final bool enabled;

  /// 광고 한 번 시청에 지급되는 크레딧.
  final int creditsPerView;

  /// 오늘 광고로 더 받을 수 있는 횟수.
  final int remainingToday;

  factory AdRewardOffer.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    if (enabled is! bool) throw const FormatException('enabled 가 없다');
    return AdRewardOffer(
      enabled: enabled,
      creditsPerView: _int(json, 'creditsPerView'),
      remainingToday: _int(json, 'remainingToday'),
    );
  }

  /// 지금 버튼을 보일 수 있는가. 서버 설정이 꺼졌거나 오늘 횟수가 없으면 숨긴다.
  bool get canOffer => enabled && creditsPerView > 0 && remainingToday > 0;
}

/// 시청 한 번을 서버에 묶는 세션 — `POST /api/credits/ad-rewards/sessions`.
@immutable
class AdRewardSession {
  const AdRewardSession({
    required this.nonce,
    required this.creditsPerView,
    required this.remainingToday,
  });

  /// 광고 요청의 customData 로 실어 보내는 한 번용 값. **로그에 남기지 않는다.**
  final String nonce;
  final int creditsPerView;
  final int remainingToday;

  factory AdRewardSession.fromJson(Map<String, dynamic> json) {
    final nonce = json['nonce'];
    if (nonce is! String || nonce.isEmpty) {
      throw const FormatException('nonce 가 없다');
    }
    return AdRewardSession(
      nonce: nonce,
      creditsPerView: _optionalInt(json['creditsPerView']),
      remainingToday: _optionalInt(json['remainingToday']),
    );
  }
}

/// 세션의 진행 상태. 서버 `AdRewardStatus` 와 1:1 이다.
enum AdRewardPhase {
  pending('PENDING'),
  granted('GRANTED'),
  rejected('REJECTED'),
  expired('EXPIRED');

  const AdRewardPhase(this.wire);

  final String wire;

  /// 모르는 값은 null — 새 상태를 서버가 먼저 배포해도 앱이 지급으로 오해하지 않는다.
  static AdRewardPhase? from(Object? raw) {
    for (final phase in values) {
      if (phase.wire == raw) return phase;
    }
    return null;
  }
}

/// `GET /api/credits/ad-rewards/sessions/{nonce}` 응답.
@immutable
class AdRewardSessionStatus {
  const AdRewardSessionStatus({
    required this.phase,
    this.grantedCredits = 0,
    this.reason,
  });

  final AdRewardPhase phase;

  /// 지급된 크레딧. 지급되지 않았으면 0.
  final int grantedCredits;

  /// [AdRewardPhase.rejected] 일 때만: DISABLED · AD_UNIT · NOT_PENDING · EXPIRED · FROZEN · DAILY_LIMIT
  final String? reason;

  factory AdRewardSessionStatus.fromJson(Map<String, dynamic> json) {
    final phase = AdRewardPhase.from(json['status']);
    if (phase == null) throw FormatException('모르는 상태', json['status']);
    return AdRewardSessionStatus(
      phase: phase,
      grantedCredits: _optionalInt(json['grantedCredits']),
      reason: json['reason']?.toString(),
    );
  }
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw FormatException('$key 가 정수가 아니다', value);
}

int _optionalInt(Object? raw) => switch (raw) {
  final int v => v,
  final num v when v == v.roundToDouble() => v.toInt(),
  _ => 0,
};
