import 'dart:ui' show Rect;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// 시스템 공유 시트로 문구를 보낸다. 실패하면 던진다 — 알리는 일은 부른 화면의 몫이다.
///
/// 테스트는 OS 가 띄우는 시트 대신 가짜를 넣는다.
/// [sharePositionOrigin] 은 아이패드 팝오버 기준 사각형 (누른 버튼 영역)
typedef InviteSharer =
    Future<void> Function(String text, Rect? sharePositionOrigin);

/// 새 패키지를 들이지 않는다 — `share_plus` 는 개발자 도구의 로그 내보내기가 이미 쓴다.
/// 아이패드는 공유 시트가 팝오버라 [sharePositionOrigin] 이 없으면 예외가 난다.
Future<void> shareWithSystemSheet(
  String text,
  Rect? sharePositionOrigin,
) async {
  await SharePlus.instance.share(
    ShareParams(text: text, sharePositionOrigin: sharePositionOrigin),
  );
}

final inviteSharerProvider = Provider<InviteSharer>(
  (ref) => shareWithSystemSheet,
);
