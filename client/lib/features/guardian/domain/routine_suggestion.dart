import 'package:flutter/foundation.dart';

/// 추천 일과 — 서버 `GET /api/routines/suggestions` 응답.
///
/// 출처: server/.../routine/application/dto/response/RoutineSuggestionResponse.java
/// (`icon` / `text` 두 필드. 서버가 50개 카탈로그에서 셔플해 돌려준다)
///
/// **개수를 고정하지 않는다.** 서버가 몇 개를 주든 화면이 깨지지 않아야 한다.
/// enum이었다가 클래스로 바꾼 이유가 이것이다. (이슈 #36)
///
/// **색은 여기 없다.** 서버가 주지 않으므로 화면이 인덱스로 배정한다
/// (`RecommendedRoutineStrip._palette`). 디자인 값을 서버가 알아야 하는
/// 구조가 되면 관리 지점이 둘로 나뉜다.
@immutable
class RoutineSuggestion {
  const RoutineSuggestion({
    required this.icon,
    required this.text,
    this.prompt = '',
  });

  /// 유니코드 이모지. 앱 폰트가 아니라 OS 이모지로 렌더링된다.
  final String icon;

  /// 타일·칩에 보이는 짧은 라벨. 타일이 86×105로 좁아 명사구다.
  final String text;

  /// 입력창에 채울 자연어 문장 (예: "비 오는 날 우산 챙겨서 학교 가는 준비를
  /// 하고 싶어요"). **서버가 아직 안 줄 수 있어 기본값이 빈 문자열이다.**
  ///
  /// [text]를 그대로 입력창에 넣으면 명사구라 보호자가 직접 쓴 문장으로 보이지
  /// 않고, AI에 전달되는 맥락도 얇다. 그래서 표시용과 입력용을 나눈다. (이슈 #39)
  final String prompt;

  /// 서버 응답 파싱. 필드가 비거나 타입이 달라도 예외를 던지지 않는다.
  factory RoutineSuggestion.fromJson(Map<String, dynamic> json) {
    return RoutineSuggestion(
      icon: json['icon']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      prompt: json['prompt']?.toString() ?? '',
    );
  }

  /// 칩에 보이는 문구 — 이모지 + 라벨.
  String get label => icon.isEmpty ? text : '$icon $text';

  /// 입력창에 채울 문구.
  ///
  /// 서버가 [prompt]를 주면 그것을, 없으면 [text]로 폴백한다.
  /// 폴백 덕분에 서버 배포 전에도 지금과 동일하게 동작한다.
  String get inputText => prompt.isNotEmpty ? prompt : text;

  /// 서버가 죽었을 때 쓰는 대체 목록.
  ///
  /// **API가 붙어도 지우지 않는다.** 추천이 비면 홈 화면 한 블록이 통째로
  /// 사라져 빈 화면처럼 보인다. 데모는 어떤 실패에서도 진행되어야 한다
  /// (docs 원칙 6번). 문구는 Figma `보호자_홈`(217:2655) 원본이다.
  // FIXME: 백엔드 #39 대기 — prompt는 서버가 내려줄 값이다.
  // 지금은 클라이언트가 임시로 들고 있다. 서버가 prompt를 주기 시작하면
  // 이 문장들은 fallback 전용으로만 남고, 정상 경로에서는 쓰이지 않는다.
  static const fallback = [
    RoutineSuggestion(
      icon: '☔️',
      text: '비 오는 날 등교',
      prompt: '비 오는 날 우산 챙겨서 학교 가는 준비를 하고 싶어요',
    ),
    RoutineSuggestion(
      icon: '🏥',
      text: '병원 방문 준비',
      prompt: '아이와 함께 병원에 가야 하는데 무서워하지 않게 준비하고 싶어요',
    ),
    RoutineSuggestion(
      icon: '🍱',
      text: '체험학습 준비',
      prompt: '체험학습 가는 날 아침에 챙길 것들을 순서대로 알려주고 싶어요',
    ),
    RoutineSuggestion(
      icon: '🚗',
      text: '새로운 장소 방문',
      prompt: '처음 가보는 장소에 가기 전에 아이가 마음의 준비를 하게 돕고 싶어요',
    ),
  ];

  @override
  bool operator ==(Object other) =>
      other is RoutineSuggestion && other.icon == icon && other.text == text;

  @override
  int get hashCode => Object.hash(icon, text);
}
