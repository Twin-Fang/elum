/// 일과 하나의 로컬 진행 기록 — 기기가 진실이다 (이슈 #140).
///
/// 서버 `completed`는 참고값이고, 이 기록이 있으면 이것이 화면 기준이다.
/// 오프라인에서 체크한 내용이 서버에 아직 없어도 화면은 이 기록을 보여준다.
///
/// Freezed를 쓰지 않는 이유: 필드 두 개짜리 값 객체라 코드 생성이 더 비싸다.
class RoutineProgressRecord {
  const RoutineProgressRecord({
    this.completed = const {},
    this.rewarded = const {},
  });

  /// 완료로 표시한 카드 id. 해제하면 빠진다.
  final Set<String> completed;

  /// 보상을 이미 보여준 카드 id. **해제해도 남는다** — 재체크 때 또 축하하지 않는다.
  final Set<String> rewarded;

  RoutineProgressRecord copyWith({
    Set<String>? completed,
    Set<String>? rewarded,
  }) {
    return RoutineProgressRecord(
      completed: completed ?? this.completed,
      rewarded: rewarded ?? this.rewarded,
    );
  }

  Map<String, dynamic> toJson() => {
    'completed': completed.toList(),
    'rewarded': rewarded.toList(),
  };

  /// 저장소가 깨져 있어도 죽지 않는다 — 필드가 없으면 빈 집합.
  factory RoutineProgressRecord.fromJson(Map<String, dynamic> json) {
    return RoutineProgressRecord(
      completed: _stringSet(json['completed']),
      rewarded: _stringSet(json['rewarded']),
    );
  }

  static Set<String> _stringSet(Object? value) => switch (value) {
    final List<dynamic> list => list.map((e) => e.toString()).toSet(),
    _ => const {},
  };
}
