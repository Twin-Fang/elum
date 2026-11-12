/// 운영자 알림을 눌렀을 때 갈 화면 3개: 서버 `AdminMessageRoute.wire` 와 같은 값
enum AdminMessageRoute {
  home('home'),
  plan('plan'),
  myCredit('myCredit');

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
