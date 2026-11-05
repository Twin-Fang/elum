import '../../core/l10n/current_l10n.dart';

/// 카드 그림을 어떤 방식으로 만들지 (#1149): Free 2개(이모지·그림 기호), Pro 2개(AI 캐릭터·실사)
/// **글(카드 문장)은 어느 방식이든 계속 만든다.**
enum ImageStyle {
  // 순서 = 화면 배치 (Free 먼저). apiValue 는 서버 `ImageStyle` enum name 과 같아야 함
  // (어긋나면 PATCH /api/member/image-style 역직렬화 실패, CrossStackContractTest 가 대조)

  /// 이모지 그림: AI 그림 없이 서버가 고른 Twemoji 가 그림 자리를 채움
  emoji('EMOJI'),

  /// 그림 기호: AI 그림 없이 서버가 고른 Mulberry 픽토그램. 사진은 카드 수정에서 넣음
  symbol('PHOTO_ONLY'),

  /// 캐릭터 그림 (Pro): 카드마다 AI 캐릭터 그림
  character('CARTOON'),

  /// 사진 같은 그림 (Pro): 카드마다 AI 실사 그림
  realistic('REALISTIC');

  /// 새 이룸이를 만들 때 처음 골라져 있는 방식 (아동 타겟 첫인상, Free)
  ///
  /// [fromApiValue]의 기본값(캐릭터)과 다르다 — 그쪽은 서버가 값을 안 준 **기존** 이룸이를
  /// 서버 DB 기본값(CARTOON)과 맞춰 읽는 것이다.
  static const onboardingDefault = ImageStyle.emoji;

  const ImageStyle(this.apiValue);

  /// 화면 이름 (선택 카드 제목·설정 줄의 값). 호출 시점의 언어로 읽는다.
  String get label => switch (this) {
    ImageStyle.emoji => appL10n.imageStyleEmojiLabel,
    ImageStyle.symbol => appL10n.imageStyleSymbolLabel,
    ImageStyle.character => appL10n.imageStyleCharacterLabel,
    ImageStyle.realistic => appL10n.imageStyleRealisticLabel,
  };

  /// 서버 enum 값
  final String apiValue;

  /// 선택 카드의 한 줄 설명
  String get description => switch (this) {
    ImageStyle.emoji => appL10n.imageStyleEmojiDescription,
    ImageStyle.symbol => appL10n.imageStyleSymbolDescription,
    ImageStyle.character => appL10n.imageStyleCharacterDescription,
    ImageStyle.realistic => appL10n.imageStyleRealisticDescription,
  };

  /// 카드 한 장마다 AI 그림을 그리는 방식인가. 그리면 그림 한 장마다 크레딧이 더 든다 —
  /// 이모지·그림 기호는 일과 만들기 크레딧만 쓴다.
  bool get drawsCardImages =>
      this == ImageStyle.character || this == ImageStyle.realistic;

  /// Pro 전용 방식인가 (서버 권한 AI_IMAGE_GENERATION 과 짝)
  bool get isProOnly => drawsCardImages;

  /// 저장소·서버에 남은 문자열을 되돌린다.
  ///
  /// **없거나 모르는 값이면 [character]다.** 필드가 없거나 서버가 새 값을
  /// 먼저 배포한 경우에도 화면이 죽지 않고 기본 방식으로 산다. 캐릭터
  /// (`CardCharacter.fromApiValue`)처럼 null 을 돌려 호출부가 정하게 하지 않는 것은,
  /// 이 값이 "고르지 않아도 되는 설정"이라 기본값이 곧 정답이기 때문이다.
  static ImageStyle fromApiValue(String? value) {
    for (final s in ImageStyle.values) {
      if (s.apiValue == value) return s;
    }
    return ImageStyle.character;
  }
}
