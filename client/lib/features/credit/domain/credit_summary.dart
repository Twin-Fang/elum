import 'package:flutter/foundation.dart';

import '../../../core/network/server_error_code.dart';

/// 진행 중인 생성 작업 한 건 — `inProgress[]`.
@immutable
class CreditJob {
  const CreditJob({required this.jobId, required this.kind, this.startedAt});

  final String jobId;

  /// `ROUTINE_CREATE` · `CARD_IMAGE` · `IMAGE_REGENERATE`
  final String kind;
  final DateTime? startedAt;
}

/// 이번 주 AI 크레딧 — 서버 `GET /api/credits/me` (#407 스펙 §3).
///
/// **모르는 값을 0 으로 채우지 않는다.** 잔액·지급량·초기화 시각이 빠지면
/// [FormatException] 을 던지고, 저장소가 실패로 바꿔 화면이 `다시 하기`를 띄운다.
/// 0 을 그리면 보호자는 크레딧을 다 썼다고 믿는다 (Review Focus 5).
///
/// 보조 값(보너스·사용·예약·단가·최대 카드 수)은 없으면 서버 기본값으로 읽는다 —
/// 그 값들이 틀려도 "남은 양" 이라는 핵심을 속이지는 않는다.
@immutable
class CreditSummary {
  const CreditSummary({
    required this.enabled,
    this.available = 0,
    this.weeklyGrant = 0,
    this.bonus = 0,
    this.used = 0,
    this.reserved = 0,
    this.periodStart,
    this.nextResetAt,
    this.routineTextCost = 1,
    this.cardImageCost = 1,
    this.maxCardsPerRoutine = 10,
    this.inProgress = const [],
    this.canStartRoutine = true,
    this.canGenerateImage = true,
  });

  /// 크레딧 정책이 꺼져 있다 — 설정 카드를 그리지 않고 홈도 막지 않는다.
  const CreditSummary.disabled() : this(enabled: false);

  final bool enabled;
  final int available;
  final int weeklyGrant;

  /// 주간이 아닌 유효 적립(관리자 보너스 등)의 남은 양.
  final int bonus;
  final int used;
  final int reserved;
  final DateTime? periodStart;
  final DateTime? nextResetAt;
  final int routineTextCost;
  final int cardImageCost;
  final int maxCardsPerRoutine;
  final List<CreditJob> inProgress;
  final bool canStartRoutine;
  final bool canGenerateImage;

  factory CreditSummary.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    if (enabled is! bool) throw const FormatException('enabled 가 없다');
    // 꺼져 있으면 나머지는 볼 일이 없다 — 서버가 비워 보내도 된다.
    if (!enabled) return const CreditSummary.disabled();

    final costs = json['costs'];
    return CreditSummary(
      enabled: true,
      available: _requireInt(json, 'available'),
      weeklyGrant: _requireInt(json, 'weeklyGrant'),
      bonus: _optionalInt(json['bonus'], 0),
      used: _optionalInt(json['used'], 0),
      reserved: _optionalInt(json['reserved'], 0),
      periodStart: DateTime.tryParse(json['periodStart']?.toString() ?? ''),
      nextResetAt: _requireDate(json, 'nextResetAt'),
      routineTextCost: _optionalInt(costs is Map ? costs['routineText'] : null, 1),
      cardImageCost: _optionalInt(costs is Map ? costs['cardImage'] : null, 1),
      maxCardsPerRoutine: _optionalInt(json['maxCardsPerRoutine'], 10),
      inProgress: switch (json['inProgress']) {
        final List<dynamic> list => [
          for (final item in list)
            if (item is Map && item['kind'] != null)
              CreditJob(
                jobId: item['jobId']?.toString() ?? '',
                kind: item['kind'].toString(),
                startedAt: DateTime.tryParse(item['startedAt']?.toString() ?? ''),
              ),
        ],
        _ => const [],
      },
      canStartRoutine: _requireBool(json, 'canStartRoutine'),
      canGenerateImage: json['canGenerateImage'] is bool
          ? json['canGenerateImage'] as bool
          : true,
    );
  }

  /// 직전 안내 기준 — 일과 하나가 최대로 쓸 수 있는 양(글 1 + 카드 10장 × 1 = 11).
  /// 이보다 적으면 "끝까지 만들어지지만 0 이 될 수 있다" 고 미리 알린다.
  int get lowThreshold => routineTextCost + maxCardsPerRoutine * cardImageCost;

  bool get isLow => available < lowThreshold;

  bool get isExhausted => available <= 0;

  /// 지금 일과를 만들고 있다 — 설정 카드에 한 줄로 알린다.
  bool get isGeneratingRoutine =>
      inProgress.any((job) => job.kind == 'ROUTINE_CREATE');

  /// 막대 길이. 분모는 이번 주에 받은 전부(주간 + 보너스)다.
  double get remainingRatio {
    final total = weeklyGrant + bonus;
    if (total <= 0) return 0;
    return (available / total).clamp(0.0, 1.0);
  }

  /// `9월 28일(월) 0시` — 초기화 줄과 홈 막기 팝업이 함께 쓴다.
  String get resetLabel {
    final at = nextResetAt;
    if (at == null) return '다음 주 월요일 0시';
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    final minute = at.minute == 0 ? '' : ' ${at.minute}분';
    return '${at.month}월 ${at.day}일(${days[at.weekday - 1]}) ${at.hour}시$minute';
  }

  static int _requireInt(Map<String, dynamic> json, String key) {
    final value = _asInt(json[key]);
    if (value == null) throw FormatException('$key 가 정수가 아니다', json[key]);
    return value;
  }

  static int _optionalInt(Object? raw, int fallback) => _asInt(raw) ?? fallback;

  static int? _asInt(Object? raw) => switch (raw) {
    final int v => v,
    final num v when v == v.roundToDouble() => v.toInt(),
    _ => null,
  };

  static DateTime _requireDate(Map<String, dynamic> json, String key) {
    final value = DateTime.tryParse(json[key]?.toString() ?? '');
    if (value == null) throw FormatException('$key 가 날짜가 아니다', json[key]);
    return value;
  }

  static bool _requireBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! bool) throw FormatException('$key 가 없다', value);
    return value;
  }
}

/// 다시 해도 풀리지 않는 크레딧 실패 — 생성 실패 화면이 `다시 하기` 대신 `홈으로`를 둔다.
///
/// 장부 오류(`AI_CREDIT_UNAVAILABLE`)는 빠진다 — 잠시 뒤에 다시 하면 된다.
/// [code] 는 흐름 상태의 에러 배지(`AppFailure.badgeOr`) 값이다.
bool isCreditBlockingCode(String? code) => const {
  ServerErrorCode.aiCreditInsufficient,
  ServerErrorCode.aiCreditJobInProgress,
  ServerErrorCode.aiCreditAccountFrozen,
}.any((c) => c.wire == code);
