import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// 시스템 공유 시트로 문구를 보낸다. 실패하면 던진다 — 알리는 일은 부른 화면의 몫이다.
///
/// 테스트는 OS 가 띄우는 시트 대신 가짜를 넣는다.
typedef InviteSharer = Future<void> Function(String text);

/// 새 패키지를 들이지 않는다 — `share_plus` 는 개발자 도구의 로그 내보내기가 이미 쓴다.
/// 휴대폰 전용 앱이라 아이패드용 팝오버 위치(`sharePositionOrigin`)는 필요 없다.
Future<void> shareWithSystemSheet(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}

final inviteSharerProvider = Provider<InviteSharer>((ref) => shareWithSystemSheet);
