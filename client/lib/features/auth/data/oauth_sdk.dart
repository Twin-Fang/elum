import 'package:flutter/services.dart';
import 'package:flutter_naver_login/flutter_naver_login.dart';
import 'package:flutter_naver_login/interface/types/naver_login_status.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';

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

/// 제공자 SDK 호출 결과.
///
/// **취소와 실패를 나눈다.** 사용자가 스스로 닫은 것에 에러를 띄우면
/// 자기가 뭘 잘못한 줄 안다. 취소는 조용히 로그인 화면에 머문다.
sealed class OAuthSdkOutcome {
  const OAuthSdkOutcome();
}

class OAuthSdkSuccess extends OAuthSdkOutcome {
  const OAuthSdkSuccess(this.token);

  /// 제공자가 준 토큰. 카카오·네이버는 액세스 토큰, 구글·애플은 ID 토큰이다.
  final String token;
}

class OAuthSdkCancelled extends OAuthSdkOutcome {
  const OAuthSdkCancelled();
}

class OAuthSdkFailure extends OAuthSdkOutcome {
  const OAuthSdkFailure(this.code);

  /// 화면에 함께 노출할 식별자. 제보를 받았을 때 어디서 터졌는지 추적한다.
  final String code;
}

/// 제공자 SDK를 감싼다. 서버 통신은 하지 않고 **토큰을 받아오는 것까지만** 한다.
///
/// 네 제공자의 API가 제각각이라 호출부가 분기를 떠안으면 화면 코드가 지저분해진다.
/// 여기서 차이를 흡수하고 밖으로는 토큰 문자열 하나만 내보낸다.
class OAuthSdk {
  bool _googleInitialized = false;

  /// 앱 시작 시 한 번 호출한다. 카카오는 SDK 초기화가 선행돼야 로그인이 동작한다.
  static Future<void> initialize() async {
    final kakaoKey = AppConfig.kakaoNativeAppKey;
    if (kakaoKey.isEmpty) {
      // 키가 없으면 카카오 버튼만 실패한다. 앱 전체를 막지 않는다.
      AppLogger.error('카카오 SDK', '네이티브 앱 키가 비어 있다');
      return;
    }
    // customScheme을 함께 넘겨야 카카오톡에서 돌아올 때 앱이 열린다.
    await KakaoSdk.init(nativeAppKey: kakaoKey);
  }

  Future<OAuthSdkOutcome> signIn(OAuthProvider provider) async {
    try {
      return switch (provider) {
        OAuthProvider.kakao => await _kakao(),
        OAuthProvider.naver => await _naver(),
        OAuthProvider.google => await _google(),
        OAuthProvider.apple => await _apple(),
      };
    } catch (e, st) {
      AppLogger.error('소셜 로그인 ${provider.label}', e, st);
      return OAuthSdkFailure('SDK-${provider.name.toUpperCase()}');
    }
  }

  /// 카카오톡이 깔려 있으면 앱으로, 아니면 웹 계정 로그인으로 간다.
  ///
  /// 카카오톡이 설치돼 있어도 실패할 수 있다(로그아웃 상태, 구버전 등).
  /// 그때 그냥 실패시키면 사용자는 로그인할 방법이 없으므로 계정 로그인으로 넘긴다.
  Future<OAuthSdkOutcome> _kakao() async {
    OAuthToken token;
    if (await isKakaoTalkInstalled()) {
      try {
        token = await UserApi.instance.loginWithKakaoTalk();
      } on PlatformException catch (e) {
        if (_isKakaoCancel(e)) return const OAuthSdkCancelled();
        AppLogger.error('카카오톡 로그인', e);
        token = await UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      try {
        token = await UserApi.instance.loginWithKakaoAccount();
      } on PlatformException catch (e) {
        if (_isKakaoCancel(e)) return const OAuthSdkCancelled();
        rethrow;
      }
    }
    return OAuthSdkSuccess(token.accessToken);
  }

  bool _isKakaoCancel(PlatformException e) =>
      e.code == 'CANCELED' || e.code == 'CANCELLED';

  /// 네이버는 상태값이 `loggedIn / loggedOut / error` 셋뿐이라
  /// **사용자 취소를 상태로 구분할 수 없다.** 에러 메시지에 cancel이 들어오면
  /// 취소로 본다. 판단이 어긋나도 "실패" 안내가 뜰 뿐 흐름은 막히지 않는다.
  Future<OAuthSdkOutcome> _naver() async {
    final result = await FlutterNaverLogin.logIn();
    if (result.status != NaverLoginStatus.loggedIn) {
      final message = result.errorMessage ?? '';
      if (message.toLowerCase().contains('cancel')) {
        return const OAuthSdkCancelled();
      }
      AppLogger.error('네이버 로그인', message.isEmpty ? result.status : message);
      return const OAuthSdkFailure('SDK-NAVER');
    }
    // logIn() 결과에 토큰이 비어 오는 경우가 있어 현재 토큰을 따로 읽는다.
    final token = await FlutterNaverLogin.getCurrentAccessToken();
    if (token.accessToken.isEmpty) {
      return const OAuthSdkFailure('SDK-NAVER-TOKEN');
    }
    return OAuthSdkSuccess(token.accessToken);
  }

  /// 구글은 **ID 토큰**을 받는다. 안드로이드에서 이 값이 나오려면
  /// `serverClientId`에 **웹 클라이언트 ID**를 넘겨야 한다. 안드로이드 클라이언트
  /// ID를 넣으면 idToken이 null로 온다.
  Future<OAuthSdkOutcome> _google() async {
    final serverClientId = AppConfig.googleServerClientId;
    if (serverClientId.isEmpty) {
      AppLogger.error('구글 로그인', '웹 클라이언트 ID가 비어 있다');
      return const OAuthSdkFailure('SDK-GOOGLE-CONFIG');
    }

    if (!_googleInitialized) {
      final iosClientId = AppConfig.googleIosClientId;
      await GoogleSignIn.instance.initialize(
        clientId: iosClientId.isEmpty ? null : iosClientId,
        serverClientId: serverClientId,
      );
      _googleInitialized = true;
    }

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      return const OAuthSdkFailure('SDK-GOOGLE-UNSUPPORTED');
    }

    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        // 대개 serverClientId 설정이 잘못된 경우다.
        AppLogger.error('구글 로그인', 'idToken이 비어 있다');
        return const OAuthSdkFailure('SDK-GOOGLE-TOKEN');
      }
      return OAuthSdkSuccess(idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const OAuthSdkCancelled();
      }
      AppLogger.error('구글 로그인', e);
      return OAuthSdkFailure('SDK-GOOGLE-${e.code.name}');
    }
  }

  /// 애플은 최초 로그인에만 이름을 준다. 지금은 이름을 쓰지 않으므로
  /// 이메일 범위만 요청한다.
  Future<OAuthSdkOutcome> _apple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        return const OAuthSdkFailure('SDK-APPLE-TOKEN');
      }
      return OAuthSdkSuccess(idToken);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const OAuthSdkCancelled();
      }
      AppLogger.error('애플 로그인', e);
      return OAuthSdkFailure('SDK-APPLE-${e.code.name}');
    }
  }
}
