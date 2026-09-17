package kr.twinfang.elum

import io.flutter.embedding.android.FlutterFragmentActivity

// 네이버 로그인 SDK가 FragmentActivity를 요구한다.
// FlutterActivity로 두면 로그인 시점에 캐스팅 실패로 죽는다.
class MainActivity : FlutterFragmentActivity()
