import 'package:flutter/foundation.dart';

/// 이룸이별 AI 메모 (`GET /api/routine-memory`, 서버 RoutineMemoryResponse)
///
/// 보호자가 고쳐 확정한 카드에서 AI 가 정리한 카드 만들기 방식. 원문·진단은 들지 않는다.
@immutable
class RoutineMemory {
  const RoutineMemory({
    required this.isAvailable,
    required this.isEnabled,
    required this.lines,
    this.lastBuiltAt,
  });

  /// 최대 줄 수 (서버 RoutineMemoryLine.MAX_LINES 와 같은 값)
  static const maxLineCount = 10;

  /// 한 줄 최대 글자 수 (서버 RoutineMemorySafetyFilter.MAX_LINE_LENGTH 와 같은 값)
  static const maxLineLength = 60;

  /// 이 계정이 쓸 수 있는가 (Pro). false 면 화면을 열 이유가 없다
  final bool isAvailable;

  /// 켜짐: 일과 만들기에 넣고 새 확정을 배운다
  final bool isEnabled;

  final List<RoutineMemoryLine> lines;

  /// AI 가 마지막으로 메모를 고친 때. 아직 없으면 null
  final DateTime? lastBuiltAt;

  bool get canAddLine => lines.length < maxLineCount;

  List<String> get lineTexts => lines.map((line) => line.text).toList();

  RoutineMemory copyWith({bool? isEnabled, List<RoutineMemoryLine>? lines}) => RoutineMemory(
        isAvailable: isAvailable,
        isEnabled: isEnabled ?? this.isEnabled,
        lines: lines ?? this.lines,
        lastBuiltAt: lastBuiltAt,
      );

  /// 응답 파싱. 필드가 비거나 모양이 달라도 던지지 않는다 (모르면 못 쓰는 것으로)
  factory RoutineMemory.fromJson(Map<String, dynamic> json) {
    return RoutineMemory(
      isAvailable: json['available'] == true,
      isEnabled: json['enabled'] != false,
      lines: switch (json['lines']) {
        final List<dynamic> list => list.map(RoutineMemoryLine.tryParse).whereType<RoutineMemoryLine>().toList(),
        _ => const <RoutineMemoryLine>[],
      },
      lastBuiltAt: json['lastBuiltAt'] is String ? DateTime.tryParse(json['lastBuiltAt'] as String) : null,
    );
  }
}

/// 메모 한 줄
@immutable
class RoutineMemoryLine {
  const RoutineMemoryLine({required this.text, required this.isWrittenByGuardian});

  final String text;

  /// 보호자가 쓰거나 고친 줄 (서버 source GUARDIAN). AI 갱신이 덮어쓰지 않는다
  final bool isWrittenByGuardian;

  static RoutineMemoryLine? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    if (text is! String || text.trim().isEmpty) return null;
    return RoutineMemoryLine(text: text, isWrittenByGuardian: raw['source'] == 'GUARDIAN');
  }
}
