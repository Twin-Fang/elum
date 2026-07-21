/// 아이가 온보딩에서 고르는 "친구" — 생성된 행동 카드 속 주인공이 된다.
///
/// 카드 이미지 콘텐츠의 일부이며, 서비스 화자(AgentPersona)와는 역할이 다르다.
enum CardCharacter {
  cat('고양이', 'CAT'),
  fox('여우', 'FOX');

  const CardCharacter(this.label, this.apiValue);

  final String label;
  final String apiValue;
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
