/// 아이가 온보딩에서 고르는 "친구" — 생성된 행동 카드 속 주인공이 된다.
///
/// 카드 이미지 콘텐츠의 일부이며, 서비스 화자(AgentPersona)와는 역할이 다르다.
enum CardCharacter {
  cat('고양이', 'CAT', '이루미'),
  fox('여우', 'FOX', '루미');

  const CardCharacter(this.label, this.apiValue, this.displayName);

  /// 종류 (접근성 안내·개발자용)
  final String label;

  final String apiValue;

  /// 카드에 표시되는 이름. 서비스명 "이룸"에서 따왔다.
  ///
  /// Figma는 이 자리를 회색 알약으로 비워뒀는데(Ellipse 2/3), 이름이 정해져
  /// 텍스트로 채운다. 아동이 부르는 이름이므로 2~3음절로 짧게 둔다.
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
