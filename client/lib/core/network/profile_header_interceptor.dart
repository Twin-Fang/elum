import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// 보호자가 고른 이룸이를 모든 요청에 `X-Profile-Id` 로 싣는다.
///
/// 헤더가 없으면 서버는 "가장 먼저 합류한 이룸이"를 쓴다. 그래서 이룸이를 바꿨는데 요청에
/// 헤더가 빠지면 **일과가 안 바뀌는 조용한 결함**이 된다 — 이룸이를 고르는 일은 이
/// 인터셉터 한 곳이 맡는다.
///
/// ## 싣지 않는 자리
///
/// - `/api/auth/*` — 로그인·갱신은 이룸이와 무관하다.
/// - [skipKey] 를 단 요청 — 고른 이룸이를 잃었을 때 헤더 없이(=첫 이룸이로) 다시 읽는 길이다.
/// - 이룸이 휴대폰 — [profileId] 콜백이 null 을 준다. 서버는 이룸이 휴대폰이 연결된 이룸이
///   말고 다른 이룸이를 지정하면 403 을 준다.
///
/// ## 실패를 두 갈래로 알린다
///
/// - 실은 이룸이가 `403 PROFILE_ACCESS_DENIED` → [onProfileLost]. 다른 휴대폰에서 그 이룸이를
///   나갔거나 지워진 경우다. 듣는 쪽이 선택을 풀고 첫 이룸이로 되돌린다.
/// - 헤더 없이 `404 PROFILE_NOT_FOUND` → [onNoProfile]. 연결된 이룸이가 하나도 없다 (E29).
///
/// 실패 자체는 그대로 흘려보낸다 — 판정은 [FailureInterceptor] 가 이어서 한다.
class ProfileHeaderInterceptor extends Interceptor {
  ProfileHeaderInterceptor({
    required this.profileId,
    this.onProfileLost,
    this.onNoProfile,
  });

  static const headerName = 'X-Profile-Id';

  /// 요청에 이 키가 true 면 헤더를 싣지 않는다.
  static const skipKey = 'skipProfileHeader';

  /// 이 요청이 실제로 어느 이룸이를 달고 나갔는지. 실패했을 때 "무엇을 잃었는지" 알려면
  /// 요청 시점의 값이 필요하다 — 실패가 돌아올 때 선택이 이미 바뀌었을 수 있다.
  static const _sentKey = 'profileHeaderSent';

  /// 지금 고른 이룸이. 없거나 보내면 안 되는 자리(이룸이 휴대폰)면 null.
  final String? Function() profileId;

  final ValueChanged<String>? onProfileLost;
  final VoidCallback? onNoProfile;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final skip =
        options.path.startsWith('/api/auth') || options.extra[skipKey] == true;
    if (!skip) {
      final id = profileId();
      if (id != null && id.isNotEmpty) {
        options.headers[headerName] = id;
        options.extra[_sentKey] = id;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final data = err.response?.data;
    final code = data is Map ? data['errorCode']?.toString() : null;
    final sent = err.requestOptions.extra[_sentKey];

    if (code == 'PROFILE_ACCESS_DENIED' && sent is String) {
      onProfileLost?.call(sent);
    } else if (code == 'PROFILE_NOT_FOUND' && sent == null) {
      onNoProfile?.call();
    }
    handler.next(err);
  }
}
