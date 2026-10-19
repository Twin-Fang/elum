/// 서버 push-devices 가 받는 플랫폼 값
enum PushPlatform {
  ios('IOS'),
  android('ANDROID');

  const PushPlatform(this.wire);

  /// 서버가 받는 문자열 그대로
  final String wire;
}
