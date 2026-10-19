/// 서버가 받는 제공자 이름. 경로 변수 `/api/auth/oauth/{provider}`에 그대로 들어간다.
enum OAuthProvider {
  kakao,
  naver,
  google,
  apple;

  String get path => name;

  String get label => switch (this) {
        OAuthProvider.kakao => '카카오',
        OAuthProvider.naver => '네이버',
        OAuthProvider.google => '구글',
        OAuthProvider.apple => '애플',
      };
}
