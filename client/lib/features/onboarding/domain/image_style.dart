/// 카드 그림을 어떤 방식으로 만들지 (이슈 #458 · 서버 #457).
///
/// 현장 피드백 — 만화풍 그림은 발달장애인에게 추상적이라 옷장 그림을 옷장으로
/// 알아보지 못할 수 있다. 실제 물건 사진 같은 그림, 또는 보호자가 직접 찍은 사진이
/// 필요해 방식을 고르게 한다. **글(카드 문장)은 어느 방식이든 계속 만든다.**
///
/// 문구는 시안이 나오기 전 **임시**다(디자이너 확정 전 제시용, 이슈 #458).
enum ImageStyle {
  // 순서가 화면 배치다 — 만화(기본)가 맨 위. 바꾸면 화면이 조용히 뒤집히므로
  // 테스트로 고정해 뒀다.
  //
  // apiValue 는 서버 `ImageStyle` enum name 과 같아야 한다. 어긋나면
  // PATCH /api/member/image-style 이 역직렬화에 실패한다.
  cartoon('만화', 'CARTOON', '캐릭터가 나오는 그림이에요'),
  realistic('실사', 'REALISTIC', '실제 물건 사진처럼 보여요'),
  photoOnly(
    '직접 찍은 사진',
    'PHOTO_ONLY',
    '그림은 직접 찍은 사진으로 넣어요. 글은 계속 만들어 드려요',
  );

  const ImageStyle(this.label, this.apiValue, this.description);

  /// 화면 이름 (선택 카드 제목·설정 줄의 값)
  final String label;

  /// 서버 enum 값
  final String apiValue;

  /// 선택 카드의 한 줄 설명
  final String description;

  /// 저장소·서버에 남은 문자열을 되돌린다.
  ///
  /// **없거나 모르는 값이면 [cartoon]이다.** 옛 서버(필드 없음)나 서버가 새 값을
  /// 먼저 배포한 경우에도 화면이 죽지 않고 기본 방식으로 산다. 캐릭터
  /// (`CardCharacter.fromApiValue`)처럼 null 을 돌려 호출부가 정하게 하지 않는 것은,
  /// 이 값이 "고르지 않아도 되는 설정"이라 기본값이 곧 정답이기 때문이다.
  static ImageStyle fromApiValue(String? value) {
    for (final s in ImageStyle.values) {
      if (s.apiValue == value) return s;
    }
    return ImageStyle.cartoon;
  }
}
