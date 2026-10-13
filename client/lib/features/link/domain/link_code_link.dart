import 'dart:math' as math;

import '../../../core/l10n/current_l10n.dart';
import '../../profile/domain/invite_link.dart';
import 'link_code.dart';

/// 이룸이 휴대폰 연결 암호 링크 — 초대 링크([InviteLink])와 같은 모양에 자리만 다르다.
///
/// | 종류 | 모양 |
/// | --- | --- |
/// | 웹 링크 | `https://twin-fang.github.io/elum/link/#code=A7K3M9` |
/// | 앱 주소 | `elum://link?code=A7K3M9` |
///
/// 해석 규칙(조각·쿼리 모두 받기, 이중 인코딩, 길이 상한)은 [InviteLink] 와 한 부품이다. 코드는 자격증명이라
/// 로그·예외 메시지에 싣지 않는다.
class LinkCodeLink {
  const LinkCodeLink._();

  /// 앱 주소의 호스트이자 웹 링크 경로의 마지막 조각.
  static const segment = 'link';

  /// [raw] 가 연결 암호 링크인지 해석한다. 결과의 뜻은 [InviteLink.parse] 와 같다.
  static InviteLink? parse(Object? raw) => InviteLink.parse(raw, segment: segment);

  static String shareUrl(String code) => InviteLink.shareUrlFor(segment, code);

  static String appUrl(String code) => InviteLink.appUrlFor(segment, code);

  /// 공유 시트에 실릴 문구 — 링크, 유효 시간, 링크가 열리지 않을 때 직접 넣을 코드.
  ///
  /// @throws ArgumentError 코드가 우리가 만들 수 없는 모양일 때. 코드는 메시지에 싣지 않는다.
  static String shareMessage(String code, {required Duration validFor}) {
    final normalized = LinkCode.normalize(code);
    // 초대 문구와 같은 올림 규칙: 발급 직후 599초를 `9분` 이라 하면 어색하다.
    final minutes = math.max(1, (validFor.inSeconds + 5) ~/ 60);
    return appL10n.linkShareMessage(
      minutes,
      shareUrl(normalized),
      LinkCode.grouped(normalized),
    );
  }
}
