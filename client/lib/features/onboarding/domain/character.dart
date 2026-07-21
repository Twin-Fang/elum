/// 아이가 온보딩에서 고르는 "친구" — 생성된 행동 카드 속 주인공이 된다.
///
/// 카드 이미지 콘텐츠의 일부이며, 서비스 화자(AgentPersona)와는 역할이 다르다.
enum CardCharacter {
  // 순서가 화면 배치다 — 고양이가 왼쪽, 여우가 오른쪽.
  // enum 순서를 바꾸면 화면이 조용히 뒤집히므로 테스트로 고정해 뒀다.
  //
  // apiValue는 서버 CharacterType enum(LULU/POPO)에 맞춘다. 서버는 캐릭터를
  // '종류'(CAT/FOX)가 아니라 '이름'(루루/포포)으로 저장하므로 프론트가 이를 따른다.
  // 어긋나면 PATCH /api/member/character가 역직렬화에 실패한다 (이슈 #89).
  cat('고양이', 'LULU', '루루'),
  fox('여우', 'POPO', '포포');

  const CardCharacter(this.label, this.apiValue, this.displayName);

  /// 종류 (접근성 안내·개발자용)
  final String label;

  /// 서버 `CharacterType` enum 값 (`LULU` / `POPO`)
  final String apiValue;

  /// 카드에 표시되는 이름.
  ///
  /// Figma는 이 자리를 회색 알약으로 비워뒀는데(Ellipse 2/3), 이름이 정해져
  /// 텍스트로 채운다. 아동이 부르는 이름이므로 2음절로 짧게 둔다.
  final String displayName;
}

/// 서비스 에이전트 — 채팅(카드 생성 대화)에서 사용자에게 말을 거는 존재.
///
/// 선택 대상이 아니다. 카드 속 주인공으로 들어가서도 안 된다.
/// CardCharacter와 한 타입으로 묶으면 병아리가 카드 주인공이 되는 버그가 가능해지므로 분리한다.
enum AgentPersona {
  chick('병아리');

  const AgentPersona(this.label);

  final String label;
}
