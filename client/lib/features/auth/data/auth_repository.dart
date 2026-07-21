import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../onboarding/application/onboarding_notifier.dart';

/// 로그인 결과. 화면이 다음 목적지를 정하는 데 쓴다.
enum AuthOutcome {
  /// 새로 만든 계정 — 온보딩을 계속한다
  created,

  /// 이미 있던 이름 — 보호자 홈으로 복귀한다
  restored,

  /// 인증 실패 — 시작 화면에 머문다
  failed,

  /// 서버에 닿지 못했다 (DNS·연결 실패·타임아웃).
  ///
  /// [failed]와 나눠둔 이유는 화면이 보여줄 문구가 다르기 때문이다. 네트워크가
  /// 끊긴 건데 "이름을 4자 이상으로" 안내하면 사용자는 이름만 계속 고치게 된다.
  offline,
}

/// 서버에 닿지 못한 실패인가. 응답 코드를 못 받은 경우가 여기에 해당한다.
bool _isOffline(Object e) {
  if (e is! DioException) return false;
  // 응답이 있으면 서버까지는 닿은 것이므로 오프라인이 아니다.
  if (e.response != null) return false;
  return switch (e.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      true,
    _ => false,
  };
}

/// 아이 이름을 아이디로 쓰는 인증.
///
/// Figma에 회원가입·로그인 화면이 **없다.** 임의로 만들면 온보딩 흐름이 끊기므로,
/// 온보딩에서 이미 받는 아이 이름을 그대로 아이디로 쓴다. (이슈 #19)
///
/// **비밀번호는 고정값이다.** 기기 ID를 쓰면 폰을 바꿨을 때 같은 이름으로 로그인할
/// 수 없다(실측: 같은 이름 + 다른 비밀번호 → 401). 고정값이면 이름만으로 계정이
/// 결정되므로 기기가 달라도 복귀된다. 해커톤 범위라 이름 충돌은 문제 삼지 않는다.
///
/// **절대 throw하지 않는다.** 인증 실패가 데모를 막으면 안 된다 (docs 원칙 6번).
class AuthRepository {
  AuthRepository({required Dio dio, required LocalStorage storage})
      : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final LocalStorage _storage;

  /// 고정 비밀번호.
  ///
  /// `0000`은 서버 제약(`@Size(min=8)`)에 걸려 400이다. 실측으로 확인했다.
  static const fixedPassword = '00000000';

  /// 이름으로 로그인한다. 회원가입과 로그인은 항상 짝으로 움직인다.
  ///
  /// 서버는 이미 있는 아이디에 409를 준다. 이 신호로 신규·복귀를 구분한다.
  Future<AuthOutcome> signInWithName(String childName) async {
    final name = childName.trim();
    if (name.isEmpty) return AuthOutcome.failed;

    final isNew = await _signUp(name);
    // 가입 단계에서 이미 서버에 못 닿았다. 로그인도 같은 결과이므로 바로 끝낸다.
    if (isNew == null) return AuthOutcome.offline;

    final token = await _login(name);
    if (token == null) {
      return _lastLoginWasOffline ? AuthOutcome.offline : AuthOutcome.failed;
    }

    return isNew ? AuthOutcome.created : AuthOutcome.restored;
  }

  /// 직전 [_login]이 서버에 닿지 못해 실패했는가.
  ///
  /// `_login`은 토큰(`String?`)을 반환해야 해서 실패 사유를 함께 돌려줄 자리가
  /// 없다. 재발급 경로([reauthenticate])와 반환 타입을 공유하므로 플래그로 뺐다.
  bool _lastLoginWasOffline = false;

  /// 가입을 시도한다. **새로 만들어졌으면 true, 기존 이름이면 false.**
  ///
  /// 409(`DUPLICATE_USERNAME`)는 오류가 아니라 "이미 있는 이름"이라는 정보다.
  /// 서버에 닿지 못하면 신규·기존을 판단할 수 없으므로 **null**을 준다.
  Future<bool?> _signUp(String username) async {
    try {
      await _dio.post<dynamic>(
        '/api/auth/signup',
        data: {'username': username, 'password': fixedPassword},
      );
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        // 기존 사용자다. 정상 경로이므로 로그인으로 넘어간다.
        return false;
      }
      if (_isOffline(e)) {
        debugPrint('[auth] 가입 실패 — 서버에 닿지 못했다: ${e.type}');
        return null;
      }
      // 이름이 4자 미만이면 서버가 400을 준다. 우회하지 않고 그대로 둔다.
      debugPrint('[auth] 가입 실패 (${e.response?.statusCode}): $e');
      return false;
    } catch (e) {
      debugPrint('[auth] 가입 중 예외: $e');
      return false;
    }
  }

  Future<String?> _login(String username) async {
    _lastLoginWasOffline = false;
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/login',
        data: {'username': username, 'password': fixedPassword},
      );

      final token = res.data?['accessToken']?.toString();
      if (token == null || token.isEmpty) {
        debugPrint('[auth] 로그인 응답에 토큰이 없다');
        return null;
      }

      await _storage.setAccessToken(token);
      return token;
    } catch (e) {
      _lastLoginWasOffline = _isOffline(e);
      if (_lastLoginWasOffline) {
        debugPrint('[auth] 로그인 실패 — 서버에 닿지 못했다');
      } else {
        debugPrint('[auth] 로그인 실패: $e');
      }
      return null;
    }
  }

  /// 저장된 이름으로 토큰을 다시 발급받는다.
  ///
  /// 토큰이 1시간 만에 만료되므로 [AuthInterceptor]가 401에서 이걸 부른다.
  /// 이름이 없으면(온보딩 전) 재발급할 방법이 없다.
  Future<String?> reauthenticate() async {
    final name = _storage.nickname;
    if (name == null || name.isEmpty) {
      debugPrint('[auth] 저장된 이름이 없어 재발급할 수 없다');
      return null;
    }
    return _login(name);
  }

  /// 토큰을 들고 있는가. 라우터 가드가 이 값으로 시작 화면 복귀를 결정한다.
  bool get hasToken {
    final token = _storage.accessToken;
    return token != null && token.isNotEmpty;
  }

  /// 회원삭제 — 서버 계정과 로컬 저장값을 모두 지운다.
  ///
  /// 로그아웃과 다르다. 로그아웃은 로컬만 지워 같은 이름으로 다시 들어가면
  /// 기존 계정에 복귀하지만, 회원삭제 후에는 같은 이름을 넣어도 **신규 가입**이 된다.
  ///
  /// **서버 삭제가 실패해도 로컬은 반드시 지운다.** 로컬에 토큰이 남으면 지워진
  /// 계정의 토큰으로 계속 401을 맞아 앱이 이상해진다. 개발자 도구에서 쓰는
  /// 기능이므로 되돌아갈 길을 막지 않는 편이 낫다.
  Future<void> deleteAccount() async {
    try {
      await _dio.delete<dynamic>('/api/member/me');
    } catch (e) {
      // 서버 삭제가 실패해도 로컬 정리는 계속한다. 토큰이 남으면 지워진 계정으로
      // 계속 401을 맞아 앱이 이상해진다.
      debugPrint('[auth] 서버 회원삭제 실패, 로컬만 정리한다: $e');
    }
    await _storage.clearAll();
  }
}

/// 인증 저장소. 인터셉터가 붙은 [dioProvider]를 쓴다.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
  );
});
