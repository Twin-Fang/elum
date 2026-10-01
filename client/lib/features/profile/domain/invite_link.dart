import 'dart:math' as math;

import '../../link/domain/link_code.dart';

/// 초대 링크 — **초대 코드를 대신 전달하는 수단** (이슈 #365).
///
/// 링크는 코드 흐름·합류 규칙을 바꾸지 않는다. 받은 사람이 링크를 누르면 코드 입력 화면에 코드가
/// 채워진 채로 열릴 뿐이고, 합류는 그 화면에서 사람이 확인 버튼을 눌러야 한다.
///
/// ## 링크 두 가지
///
/// | 종류 | 모양 | 쓰임 |
/// | --- | --- | --- |
/// | 웹 링크 | `https://twin-fang.github.io/elum/invite/#code=A7K3M9` | 공유 시트로 보내는 것. 메신저가 링크로 알아본다 |
/// | 앱 주소 | `elum://invite?code=A7K3M9` | 안내 페이지의 `앱에서 열기`가 부른다 |
///
/// **웹 링크는 코드를 조각(`#`)에 둔다.** 조각은 브라우저가 서버로 보내지 않아 게시 사이트의 접속 기록·
/// 리퍼러·분석 어디에도 남지 않는다. 안내 페이지는 자바스크립트로 조각을 읽어 앱 주소로 넘긴다.
/// 앱은 쿼리·조각을 **둘 다** 받는다 — 나중에 OS 가 웹 링크를 앱으로 직접 열어 줄 때(Universal·App
/// Links) 어느 쪽 모양이 오든 해석되어야 한다.
///
/// ## 해석 결과
///
/// [parse] 는 세 갈래로 답한다.
///
/// | 결과 | 뜻 | 앱의 동작 |
/// | --- | --- | --- |
/// | `null` | 초대 링크가 아니다 | 건드리지 않는다 (소셜 로그인 콜백 등) |
/// | `InviteLink(code: null)` | 초대 링크인데 코드를 쓸 수 없다 | 입력 화면이 에러 코드로 안내한다 |
/// | `InviteLink(code: 'A7K3M9')` | 정상 | 입력 화면에 채운다 |
///
/// 쓸 수 없는 모양은 서버에 보내지 않는다 — 보내 봐야 계정당 시도 한도만 줄어든다.
///
/// ⚠️ 코드는 자격증명이다. 이 파일은 코드를 **로그·예외 메시지에 싣지 않는다.**
class InviteLink {
  const InviteLink({required this.code});

  /// 정규화하고 모양까지 확인한 코드. 링크는 맞는데 코드가 비었거나 못 쓸 모양이면 null.
  final String? code;

  /// 앱 주소 스킴. iOS `Info.plist` 의 URL Types 와 안드로이드 매니페스트의 인텐트 필터가 같은 값을 쓴다.
  static const appScheme = 'elum';

  /// 앱 주소의 호스트이자 웹 링크 경로의 마지막 조각.
  static const _segment = 'invite';

  /// 게시 사이트(`gh-pages`)의 호스트. **스트링 비교로 정확히 맞는 것만** 받는다 — `…github.io.evil.com`
  /// 같은 겉모습만 닮은 주소를 걸러야 한다.
  static const webHost = 'twin-fang.github.io';

  /// 웹 링크의 기준 주소. 앱 식별자처럼 앱과 게시 페이지가 짝으로 정하는 값이라 `.env` 에 두지 않는다 —
  /// Secret 을 빠뜨려 빈 값이 배포돼도 증상이 없는 길을 만들 이유가 없다.
  static const webBase = 'https://$webHost/elum/$_segment/';

  /// 값 하나의 길이 상한. 우리 코드는 여섯 글자이고, 공백·하이픈·인코딩을 끼워도 이보다 길 수 없다.
  /// 이보다 길면 디코딩하지 않고 버린다 — 수만 자짜리 입력을 두 번 푸는 일을 막는다.
  static const _maxRawValue = 64;

  /// [raw] 가 초대 링크인지 해석한다. [raw] 는 문자열 또는 [Uri] 다. 어떤 입력에도 던지지 않는다.
  static InviteLink? parse(Object? raw) {
    final Uri uri;
    if (raw is Uri) {
      uri = raw;
    } else if (raw is String) {
      try {
        uri = Uri.parse(raw.trim());
      } on FormatException {
        return null;
      }
    } else {
      return null;
    }

    if (!_isInviteAddress(uri)) return null;

    // 쿼리가 먼저, 없으면 조각. 쿼리에 코드 이름이 있으면 그 값이 이긴다 (못 쓸 모양이어도 조각으로 넘어가지 않는다).
    final found = _findCodeParam(uri.query) ?? _findCodeParam(uri.fragment);
    return InviteLink(code: found == null ? null : _decodeCode(found));
  }

  /// 이 주소가 초대 링크가 가리키는 자리인가 — 앱 주소·웹 링크·플랫폼이 호스트를 뗀 경로 셋을 본다.
  static bool _isInviteAddress(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    // 호스트가 있으면 호스트도 한 조각으로 센다 (`elum://invite` 는 호스트가 invite 다).
    final segments = [
      if (scheme == appScheme && uri.host.isNotEmpty) uri.host,
      ...uri.pathSegments.where((s) => s.isNotEmpty),
    ].map((s) => s.toLowerCase()).toList();

    switch (scheme) {
      case appScheme:
        return segments.length == 1 && segments.first == _segment;
      case 'https':
        return uri.host.toLowerCase() == webHost && _isWebPath(segments);
      case '':
        // 플랫폼이 호스트를 떼고 경로만 넘기는 경우 (안드로이드 초기 라우트 등)
        return uri.host.isEmpty && (_isWebPath(segments) || _isOnlySegment(segments));
      default:
        // http, 소셜 로그인 콜백 스킴 등은 건드리지 않는다
        return false;
    }
  }

  static bool _isWebPath(List<String> segments) =>
      segments.length == 2 && segments[0] == 'elum' && segments[1] == _segment;

  static bool _isOnlySegment(List<String> segments) =>
      segments.length == 1 && segments.first == _segment;

  /// `a=1&code=X` 에서 코드 파라미터의 **인코딩된 원문** 값. 이름이 없으면 null (코드가 없는 것과 다르다).
  ///
  /// `Uri.queryParameters` 를 쓰지 않는다 — 깨진 퍼센트 인코딩에서 던지고, 같은 이름이 여럿이면
  /// 마지막 값만 남긴다. 여기서는 **첫 번째**를 쓰고 던지지 않아야 한다.
  static String? _findCodeParam(String query) {
    if (query.isEmpty) return null;
    for (final pair in query.split('&')) {
      final eq = pair.indexOf('=');
      final name = eq < 0 ? pair : pair.substring(0, eq);
      if (_safeDecode(name)?.toLowerCase() != 'code') continue;
      return eq < 0 ? '' : pair.substring(eq + 1);
    }
    return null;
  }

  /// 인코딩된 값을 코드로. 쓸 수 없으면 null.
  static String? _decodeCode(String encoded) {
    if (encoded.length > _maxRawValue) return null;

    var value = _safeDecode(encoded);
    if (value == null) return null;
    // 메신저·단축 서비스가 `%` 를 한 번 더 인코딩하는 일이 있다. **한 번만** 더 푼다 —
    // 풀어도 `%` 가 남으면 세 겹 이상이라 받지 않는다.
    if (value.contains('%')) {
      value = _safeDecode(value);
      if (value == null || value.contains('%')) return null;
    }

    final normalized = LinkCode.normalize(value.trim());
    return LinkCode.hasValidShape(normalized) ? normalized : null;
  }

  /// 퍼센트 인코딩과 `+` (공백) 을 푼다. 깨진 입력은 null — 던지지 않는다.
  static String? _safeDecode(String s) {
    try {
      return Uri.decodeQueryComponent(s);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// 공유 시트로 보낼 웹 링크. 코드는 조각에 둔다 (위 설명).
  ///
  /// @throws ArgumentError 코드가 우리가 만들 수 없는 모양일 때. 코드는 메시지에 싣지 않는다.
  static String shareUrl(String code) => '$webBase#code=${_checked(code)}';

  /// 안내 페이지의 `앱에서 열기` 가 부르는 앱 주소 (페이지 쪽 문자열과 같은 모양이어야 한다).
  static String appUrl(String code) => '$appScheme://$_segment?code=${_checked(code)}';

  static String _checked(String code) {
    final normalized = LinkCode.normalize(code);
    if (!LinkCode.hasValidShape(normalized)) {
      throw ArgumentError('초대 코드 모양이 맞지 않습니다');
    }
    return normalized;
  }

  /// 공유 시트에 실릴 문구. 해요체이고 `초대 코드` 라는 말을 쓴다 (이룸이 휴대폰의 `연결 암호` 와 구분).
  ///
  /// - 만료를 알린다. [validFor] 는 **남은** 시간이라 보내는 시점에 줄어 있을 수 있다.
  /// - 링크가 열리지 않는 곳(메신저가 막거나 앱이 없는 곳)을 위해 코드를 3-3 으로 한 번 적어 둔다.
  ///   링크 안에 이미 있는 값이라 새로 드러나는 것은 없다.
  static String shareMessage(String code, {required Duration validFor}) {
    final normalized = _checked(code);
    // 올림에 가깝게: 발급 직후 599초를 `9분` 이라 하면 어색하다. 5초까지 봐준다 (실제보다 길게 말하지는 않는다).
    final minutes = math.max(1, (validFor.inSeconds + 5) ~/ 60);
    return '이룸이를 함께 돌봐요. 아래 링크를 누르면 이룸 앱에 초대 코드가 채워져요.\n'
        '초대 코드는 $minutes분 동안만 쓸 수 있어요.\n'
        '\n'
        '${shareUrl(normalized)}\n'
        '\n'
        '링크가 열리지 않으면 앱에서 직접 넣어주세요.\n'
        '초대 코드 ${LinkCode.grouped(normalized)}';
  }
}
