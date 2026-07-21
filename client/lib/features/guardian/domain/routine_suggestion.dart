/// 일과 만들기 화면의 추천 문구 칩.
///
/// Figma `보호자_새로운 일과 만들기`(238:1643) Frame 9 — 2·2·1 배치의 5개다.
///
/// **홈의 [RecommendedRoutine](recommended_routine.dart)과 다르다.** 그쪽은 4개이고
/// 이모지도 다르다(새로운 장소: 홈 🚗 / 여기 🌱). 개수·문구가 따로 노는 별개
/// 목록이라 합치지 않는다 — 합치면 한쪽만 바꿔야 할 때 못 바꾼다.
///
/// 지금은 하드코딩이며 나중에 AI가 생성할 자리다.
enum RoutineSuggestion {
  rainyCommute('☔️ 비 오는 날 등교'),
  hospitalVisit('🏥 병원 방문 준비'),
  fieldTrip('🍱 체험학습 준비'),
  newPlace('🌱 새로운 장소 방문'),
  afterSchool('🎒 여름방학 방과후 수업 준비');

  const RoutineSuggestion(this.label);

  /// 칩에 보이는 문구. 이모지가 앞에 붙어 있다.
  final String label;

  /// 입력창에 채울 문구. 이모지는 장식이라 서버로 보내지 않는다.
  String get inputText => label.replaceFirst(RegExp(r'^\S+\s+'), '');

  /// Figma 2·2·1 배치의 앞 4개 (2열 × 2줄)
  static List<RoutineSuggestion> get paired => const [
        rainyCommute,
        hospitalVisit,
        fieldTrip,
        newPlace,
      ];

  /// 마지막 줄에 혼자 오는 항목
  static const trailing = afterSchool;
}
