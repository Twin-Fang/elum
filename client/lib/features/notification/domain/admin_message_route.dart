/// 운영자·자동 알림을 눌렀을 때 갈 화면 4개: 서버 `AdminMessageRoute.wire` 와 같은 값
enum AdminMessageRoute {
  home('home'),
  plan('plan'),
  myCredit('myCredit'),
  // 이룸이 기기 연결 (연결 코드 화면, 이미 붙어 있으면 연결 상태 화면)
  deviceLink('deviceLink');

  const AdminMessageRoute(this.wire);

  /// 서버가 보내는 문자열 그대로
  final String wire;

  /// 서버 값 > 화면 (비었거나 앱이 모르는 값이면 홈)
  static AdminMessageRoute fromServer(String? wire) {
    for (final route in values) {
      if (route.wire == wire) return route;
    }
    return home;
  }
}
