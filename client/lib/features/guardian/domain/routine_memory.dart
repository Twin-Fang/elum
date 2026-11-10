import 'package:flutter/foundation.dart';

/// 규칙 종류: 낱말 바꾸기 · 나누기 · 합치기 · 더하기 · 빼기 · 직접 적음
enum MemoryRuleType {
  word('WORD'),
  split('SPLIT'),
  merge('MERGE'),
  add('ADD'),
  remove('REMOVE'),
  manual('MANUAL');

  const MemoryRuleType(this.wire);

  final String wire;

  /// 모르는 값은 직접 적음으로 본다 (줄을 버리지 않음)
  static MemoryRuleType fromWire(Object? raw) =>
      values.firstWhere((type) => type.wire == raw, orElse: () => manual);
}

/// 규칙 상태: 적용 중 · 관찰 중 · 꺼짐
enum MemoryRuleStatus {
  active('ACTIVE'),
  watching('WATCHING'),
  off('OFF');

  const MemoryRuleStatus(this.wire);

  final String wire;

  static MemoryRuleStatus? tryParse(Object? raw) {
    for (final status in values) {
      if (status.wire == raw) return status;
    }
    return null;
  }
}

/// 규칙이 생긴 곳 (AI 가 찾음 · 보호자가 적음)
enum MemoryRuleSource { ai, manual }

/// 규칙 근거 한 줄: 어느 일과에서 언제 봤나
@immutable
class MemoryEvidence {
  const MemoryEvidence({required this.routineTitle, this.observedAt});

  final String routineTitle;
  final DateTime? observedAt;

  static MemoryEvidence? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final title = raw['routineTitle'];
    if (title is! String || title.trim().isEmpty) return null;
    return MemoryEvidence(routineTitle: title, observedAt: DateTime.tryParse('${raw['observedAt']}'));
  }
}

/// 메모리 규칙 한 줄 — 서버 `rules[]`
@immutable
class MemoryRule {
  const MemoryRule({
    required this.id,
    required this.type,
    required this.status,
    required this.source,
    required this.summary,
    this.before,
    this.after,
    this.evidenceCount = 0,
    this.evidences = const [],
  });

  final String id;
  final MemoryRuleType type;
  final MemoryRuleStatus status;
  final MemoryRuleSource source;
  final String summary;

  /// 바꾸기 전 · 후 (없을 수 있음)
  final String? before;
  final String? after;
  final int evidenceCount;
  final List<MemoryEvidence> evidences;

  bool get isManual => source == MemoryRuleSource.manual || type == MemoryRuleType.manual;

  /// 줄에 `{before} → {after}` 로 그릴 수 있는가 (아니면 summary)
  bool get hasBeforeAfter => (before ?? '').isNotEmpty && (after ?? '').isNotEmpty;

  static MemoryRule? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id']?.toString() ?? '';
    final status = MemoryRuleStatus.tryParse(raw['status']);
    final summary = raw['summary'];
    if (id.isEmpty || status == null || summary is! String || summary.trim().isEmpty) return null;
    return MemoryRule(
      id: id,
      type: MemoryRuleType.fromWire(raw['type']),
      status: status,
      source: raw['source'] == 'MANUAL' ? MemoryRuleSource.manual : MemoryRuleSource.ai,
      summary: summary,
      before: raw['before'] is String ? raw['before'] as String : null,
      after: raw['after'] is String ? raw['after'] as String : null,
      evidenceCount: raw['evidenceCount'] is num ? (raw['evidenceCount'] as num).toInt() : 0,
      evidences: switch (raw['evidences']) {
        final List<dynamic> list => list.map(MemoryEvidence.tryParse).whereType<MemoryEvidence>().toList(),
        _ => const <MemoryEvidence>[],
      },
    );
  }
}

/// 수정 기록 한 줄 — 서버 `edits[]` (일과를 고쳐 보낼 때마다)
@immutable
class MemoryEdit {
  const MemoryEdit({
    required this.routineTitle,
    this.editedAt,
    this.cardCountBefore,
    this.cardCountAfter,
    this.changedTextCount,
  });

  final String routineTitle;
  final DateTime? editedAt;
  final int? cardCountBefore;
  final int? cardCountAfter;
  final int? changedTextCount;

  static MemoryEdit? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final title = raw['routineTitle'];
    if (title is! String || title.trim().isEmpty) return null;
    int? count(String key) => raw[key] is num ? (raw[key] as num).toInt() : null;
    return MemoryEdit(
      routineTitle: title,
      editedAt: DateTime.tryParse('${raw['editedAt']}'),
      cardCountBefore: count('cardCountBefore'),
      cardCountAfter: count('cardCountAfter'),
      changedTextCount: count('changedTextCount'),
    );
  }
}

/// 보호자 한 사람의 AI 메모리 (`GET /api/routine-memory`). 다른 보호자와 공유하지 않음
///
/// AI 가 찾은 수정은 관찰 중으로 쌓이고, 보호자가 누르거나 같은 수정이 일과 [autoApplyCount] 개에서 반복되면 적용된다.
@immutable
class RoutineMemory {
  const RoutineMemory({
    required this.isEnabled,
    required this.autoApplyCount,
    required this.rules,
    required this.edits,
  });

  /// 직접 적는 글 최대 글자 수
  static const maxTextLength = 60;

  /// 서버가 안 주면 쓰는 반복 기준 (일과 개수)
  static const defaultAutoApplyCount = 3;

  final bool isEnabled;
  final int autoApplyCount;
  final List<MemoryRule> rules;
  final List<MemoryEdit> edits;

  List<MemoryRule> get activeRules => [for (final rule in rules) if (rule.status != MemoryRuleStatus.watching) rule];
  List<MemoryRule> get watchingRules => [for (final rule in rules) if (rule.status == MemoryRuleStatus.watching) rule];

  /// `적용 중` 칸 숫자: 켜져 있는 규칙 (꺼진 줄은 목록에는 있고 숫자에는 안 셈)
  int get appliedCount => rules.where((rule) => rule.status == MemoryRuleStatus.active).length;

  bool get hasNothing => rules.isEmpty && edits.isEmpty;

  /// 응답 파싱. 필드가 비거나 모양이 달라도 던지지 않는다
  factory RoutineMemory.fromJson(Map<String, dynamic> json) => RoutineMemory(
    isEnabled: json['enabled'] != false,
    autoApplyCount: json['autoApplyCount'] is num && (json['autoApplyCount'] as num) > 0
        ? (json['autoApplyCount'] as num).toInt()
        : defaultAutoApplyCount,
    rules: switch (json['rules']) {
      final List<dynamic> list => list.map(MemoryRule.tryParse).whereType<MemoryRule>().toList(),
      _ => const <MemoryRule>[],
    },
    edits: switch (json['edits']) {
      final List<dynamic> list => list.map(MemoryEdit.tryParse).whereType<MemoryEdit>().toList(),
      _ => const <MemoryEdit>[],
    },
  );
}

/// 관찰 조회 결과 상태: 계산 중 · 준비됨 · 없음
enum MemoryObservationStatus { pending, ready, none }

/// 일과를 고쳐 보낸 직후 `observations` 응답 항목 한 개
@immutable
class MemoryObservation {
  const MemoryObservation({
    required this.ruleId,
    required this.type,
    required this.summary,
    required this.ruleStatus,
    this.before,
    this.after,
    this.evidenceCount = 0,
  });

  final String ruleId;
  final MemoryRuleType type;
  final String summary;
  final MemoryRuleStatus ruleStatus;
  final String? before;
  final String? after;
  final int evidenceCount;

  static MemoryObservation? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final ruleId = raw['ruleId']?.toString() ?? '';
    final summary = raw['summary'];
    final status = MemoryRuleStatus.tryParse(raw['ruleStatus']);
    if (ruleId.isEmpty || summary is! String || status == null) return null;
    return MemoryObservation(
      ruleId: ruleId,
      type: MemoryRuleType.fromWire(raw['type']),
      summary: summary,
      ruleStatus: status,
      before: raw['before'] is String ? raw['before'] as String : null,
      after: raw['after'] is String ? raw['after'] as String : null,
      evidenceCount: raw['evidenceCount'] is num ? (raw['evidenceCount'] as num).toInt() : 0,
    );
  }
}

@immutable
class MemoryObservations {
  const MemoryObservations({required this.status, required this.items});

  static const none = MemoryObservations(status: MemoryObservationStatus.none, items: []);

  final MemoryObservationStatus status;
  final List<MemoryObservation> items;

  static MemoryObservations parse(Object? raw) {
    if (raw is! Map) return none;
    final status = switch (raw['status']) {
      'PENDING' => MemoryObservationStatus.pending,
      'READY' => MemoryObservationStatus.ready,
      _ => MemoryObservationStatus.none,
    };
    final items = switch (raw['items']) {
      final List<dynamic> list => list.map(MemoryObservation.tryParse).whereType<MemoryObservation>().toList(),
      _ => const <MemoryObservation>[],
    };
    return MemoryObservations(status: status, items: items);
  }
}
