import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/local_storage.dart';
import '../../../core/storage/token_store.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import 'oauth_sdk.dart';

/// 로그인 결과. 화면이 다음 목적지를 정하는 데 쓴다.
enum AuthOutcome {
  /// 약관 동의를 받지 않은 계정 — 동의 화면부터.
  ///
  /// 동의 없이는 서비스를 쓸 수 없으므로 아이 정보를 입력받기 전에 먼저 받는다.
  /// 온보딩을 다 하고 나서 동의를 거부하면 입력한 것이 전부 버려진다.
  consentRequired,

  /// 동의는 마쳤고 아이 정보가 없는 계정 — 온보딩을 진행한다
  onboarding,

  /// 전부 마친 계정 — 보호자 홈으로 바로 간다
  home,

  /// 사용자가 제공자 화면을 닫았다. **오류가 아니다.**
  /// 스스로 닫은 것에 에러를 띄우면 뭘 잘못한 줄 안다
  cancelled,

  /// 같은 이메일이 이미 다른 방법으로 가입돼 있다
  emailConflict,

  /// 인증 실패 — 화면에 에러 코드와 함께 재시도를 안내한다
  failed,

  /// 서버에 닿지 못했다 (DNS·연결 실패·타임아웃).
  ///
  /// [failed]와 나눠둔 이유는 보여줄 문구가 다르기 때문이다. 네트워크가 끊긴 건데
  /// "다시 로그인해 주세요"라고 하면 사용자는 로그인만 계속 누르게 된다
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

/// 소셜 로그인 기반 인증.
///
/// 제공자 SDK로 받은 토큰을 서버에 넘기면 서버가 확인 후 우리 토큰을 준다.
/// 제공자 토큰은 여기서 버린다 — 저장하지 않는다.
///
/// **절대 throw하지 않는다.** 인증 실패가 화면을 깨뜨리면 안 된다 (docs 원칙 6번).
class AuthRepository {
  AuthRepository({
    required Dio dio,
    required LocalStorage storage,
    required TokenStore tokens,
    required OAuthSdk sdk,
  })  : _dio = dio,
        _storage = storage,
        _tokens = tokens,
        _sdk = sdk;

  final Dio _dio;
  final LocalStorage _storage;
  final TokenStore _tokens;
  final OAuthSdk _sdk;

  /// 진행 중인 갱신 요청. **동시에 여러 번 갱신하지 않기 위한 장치다.**
  ///
  /// 홈 화면이 API 3개를 동시에 부르다 다 같이 401을 받으면 각자 갱신을 시도한다.
  /// 서버는 리프레시 토큰을 한 번 쓰면 폐기하는 회전 방식이라, 두 번째 요청은
  /// **탈취로 간주돼 계정의 모든 세션이 끊긴다.** 첫 요청만 실제로 보내고
  /// 나머지는 그 결과를 함께 기다린다.
  Future<String?>? _refreshInFlight;

  bool get hasSession => _tokens.hasSession;

  /// 제공자로 로그인한다.
  Future<AuthOutcome> signInWith(OAuthProvider provider) async {
    final sdkResult = await _sdk.signIn(provider);

    switch (sdkResult) {
      case OAuthSdkCancelled():
        return AuthOutcome.cancelled;
      case OAuthSdkFailure(code: final code):
        AppLogger.error('소셜 로그인', code);
        return AuthOutcome.failed;
      case OAuthSdkSuccess(token: final providerToken):
        return _exchange(provider, providerToken);
    }
  }

  /// 제공자 토큰을 우리 토큰으로 바꾼다.
  Future<AuthOutcome> _exchange(OAuthProvider provider, String providerToken) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/oauth/${provider.path}',
        data: {'token': providerToken},
      );

      final access = res.data?['accessToken']?.toString();
      final refresh = res.data?['refreshToken']?.toString();
      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
        AppLogger.error('소셜 로그인', '서버 응답에 토큰이 없다');
        return AuthOutcome.failed;
      }

      await _tokens.save(accessToken: access, refreshToken: refresh);
      // 다음 로그인 화면에서 "지난번에 이걸로 하셨어요"를 보여주기 위해 남긴다.
      // 다른 수단으로 들어와 빈 계정이 생기는 사고를 막는 장치다.
      await _storage.setLastLoginProvider(provider.name);
      return await _resolveDestination();
    } on DioException catch (e) {
      if (_isOffline(e)) return AuthOutcome.offline;
      // 409는 같은 이메일이 다른 제공자로 이미 가입된 경우다.
      // 서버가 이메일로 계정을 합치지 않기 때문에 사용자에게 안내해야 한다.
      if (e.response?.statusCode == 409) return AuthOutcome.emailConflict;
      AppLogger.error('소셜 로그인 교환', e);
      return AuthOutcome.failed;
    } catch (e) {
      AppLogger.error('소셜 로그인 교환', e);
      return AuthOutcome.failed;
    }
  }

  /// 다음에 보여줄 화면을 정한다. 요청 한 번으로 끝내기 위해 회원 정보에
  /// 동의 완료 여부를 함께 담아 받는다.
  ///
  /// 순서는 **동의 → 아이 정보 → 홈**이다. 동의를 마지막에 받으면 아이 정보를
  /// 다 입력한 뒤 거부했을 때 그 입력이 전부 버려진다.
  Future<AuthOutcome> _resolveDestination() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/member/me');

      final consented = res.data?['requiredConsentsCompleted'] == true;
      if (!consented) {
        // 동의도 하지 않은 계정이면 확실히 새 계정이다
        await _storage.clearChildProfile();
        return AuthOutcome.consentRequired;
      }

      final nickname = res.data?['nickname']?.toString();
      if (nickname == null || nickname.isEmpty) {
        // 이 계정에는 아직 아이 정보가 없다. 이전 계정의 값이 남아 있으면
        // 이름 입력칸에 남의 이름이 미리 채워지고, 거기에 입력하면 이어붙는다.
        // 토큰은 방금 받았으므로 아이 정보만 지운다. (이슈 #177)
        await _storage.clearChildProfile();
        return AuthOutcome.onboarding;
      }

      // 재설치한 기존 사용자다. 아이 이름을 로컬에도 되살려 둔다.
      await _storage.setNickname(nickname);
      return AuthOutcome.home;
    } catch (e) {
      // 조회가 실패해도 로그인 자체는 끝났다. 동의 화면부터 보내면
      // 이미 동의한 사용자는 한 번 더 누르게 되지만, 건너뛰어서 동의 없이
      // 서비스를 쓰게 되는 것보다 낫다.
      AppLogger.error('회원 정보 조회', e);
      return AuthOutcome.consentRequired;
    }
  }

  /// 리프레시 토큰으로 액세스 토큰을 다시 받는다. [AuthInterceptor]가 401에서 부른다.
  Future<String?> refreshAccessToken() {
    return _refreshInFlight ??=
        _performRefresh().whenComplete(() => _refreshInFlight = null);
  }

  Future<String?> _performRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refreshToken': refresh},
      );

      final access = res.data?['accessToken']?.toString();
      final nextRefresh = res.data?['refreshToken']?.toString();
      if (access == null || access.isEmpty || nextRefresh == null || nextRefresh.isEmpty) {
        return null;
      }

      // 회전 방식이라 리프레시 토큰도 매번 새 값으로 바뀐다. 반드시 덮어쓴다.
      await _tokens.save(accessToken: access, refreshToken: nextRefresh);
      return access;
    } on DioException catch (e) {
      if (_isOffline(e)) {
        // 네트워크 문제는 세션 문제가 아니다. 토큰을 지우면 안 된다.
        AppLogger.error('토큰 갱신', '서버에 닿지 못했다');
        return null;
      }
      // 401이면 토큰이 만료·폐기됐거나 재사용으로 감지된 것이다.
      // 어느 쪽이든 이 세션은 끝났으므로 지우고 다시 로그인시킨다.
      if (e.response?.statusCode == 401) {
        AppLogger.error('토큰 갱신', '세션이 만료되었다');
        await _tokens.clear();
      }
      return null;
    } catch (e) {
      AppLogger.error('토큰 갱신', e);
      return null;
    }
  }

  /// 로그아웃. 서버 세션을 끊고 로컬 토큰을 지운다.
  ///
  /// **서버 요청이 실패해도 로컬은 반드시 지운다.** 로컬에 남으면 사용자는
  /// 로그아웃했다고 생각하는데 앱은 로그인 상태로 동작한다.
  Future<void> logout() async {
    final refresh = _tokens.refreshToken;
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _dio.post<dynamic>('/api/auth/logout', data: {'refreshToken': refresh});
      } catch (e) {
        AppLogger.error('로그아웃', e);
      }
    }
    await _tokens.clear();
    await _storage.clearAll();
  }

  /// 회원삭제 — 서버 계정과 로컬 저장값을 모두 지운다. 지워졌으면 true.
  ///
  /// 로그아웃과 다르다. 로그아웃 후 같은 계정으로 다시 들어오면 데이터가 그대로지만,
  /// 회원삭제 후에는 같은 소셜 계정으로 로그인해도 **신규 가입**이 된다.
  ///
  /// **서버가 실패하면 로컬도 건드리지 않고 false를 돌려준다** (이슈 #187).
  /// 계정이 서버에 그대로 있는데 로컬만 비우면, 사용자는 지워진 줄 알고 떠나고
  /// 실제로는 아무것도 지워지지 않는다. 되돌릴 수 없다고 안내한 동작은 됐는지
  /// 안 됐는지를 말해야 한다.
  ///
  /// 삭제는 됐는데 응답만 유실된 경우가 남지만, 그때는 다음 요청이 401을 맞고
  /// 갱신까지 실패해 세션 종료 경로로 빠진다 (이슈 #175). 그쪽에 맡긴다.
  Future<bool> deleteAccount() async {
    try {
      await _dio.delete<dynamic>('/api/member/me');
    } catch (e) {
      AppLogger.error('회원삭제', e);
      return false;
    }
    await _tokens.clear();
    await _storage.clearAll();
    return true;
  }
}

/// 앱 전체에서 하나만 쓴다. 갱신 동시성 제어가 인스턴스 안에 있어서
/// 매번 새로 만들면 묶는 의미가 없다.
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final oAuthSdkProvider = Provider<OAuthSdk>((ref) => OAuthSdk());

/// 토큰 갱신 전용 인스턴스.
///
/// **인터셉터가 붙지 않은 Dio**를 쓴다. 갱신 요청이 401을 받았을 때 인터셉터가
/// 또 갱신을 부르면 재귀가 된다. 그리고 앱 전체에서 이 인스턴스 하나만 쓰므로
/// 동시 갱신을 묶는 장치가 실제로 동작한다.
final tokenRefresherProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: DioClient.create(),
    storage: ref.watch(localStorageProvider),
    tokens: ref.watch(tokenStoreProvider),
    sdk: ref.watch(oAuthSdkProvider),
  );
});

/// 인증 저장소. 인터셉터가 붙은 [dioProvider]를 쓴다.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    storage: ref.watch(localStorageProvider),
    tokens: ref.watch(tokenStoreProvider),
    sdk: ref.watch(oAuthSdkProvider),
  );
});
