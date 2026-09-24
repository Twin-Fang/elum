/// 서버 `GET /api/credits/me` 계약 (#407 스펙 §3).
Map<String, Object?> creditJson({
  bool enabled = true,
  int available = 72,
  int weeklyGrant = 100,
  int bonus = 0,
  bool? canStartRoutine,
  List<Object?> inProgress = const [],
}) => {
  'enabled': enabled,
  'available': available,
  'weeklyGrant': weeklyGrant,
  'bonus': bonus,
  'used': 28,
  'reserved': 0,
  'periodStart': '2026-09-21T00:00:00',
  'nextResetAt': '2026-09-28T00:00:00',
  'costs': {'routineText': 1, 'cardImage': 1},
  'maxCardsPerRoutine': 10,
  'inProgress': inProgress,
  'canStartRoutine': canStartRoutine ?? available >= 1,
  'canGenerateImage': available >= 1,
};
