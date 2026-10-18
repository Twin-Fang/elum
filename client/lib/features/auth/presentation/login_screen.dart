import 'dart:io' show Platform;
import 'login_version_corner.dart';
import 'login_last_used_slot.dart';
import 'login_provider_button.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../core/widgets/login_scene.dart';
import '../application/login_controller.dart';
import '../data/auth_repository.dart';
import '../data/oauth_sdk.dart';
import '../../../core/router/routes.dart';

/// 로그인 화면. 온보딩 맨 앞에 선다.
///
/// 계정이 먼저 생기고 그 안에 당사자 프로필을 만드는 서버 구조와 순서를 맞췄다.
/// 재설치한 사용자는 로그인만 하면 아이 정보가 서버에서 되살아난다.
///
/// **화면 그림은 [LoginScene]이 그리고, 배치는 플랫폼마다 다르다**.
/// 시안이 `로그인_iOS`(238:1808)와 `로그인_AOS`(1022:4333) 둘로 나와, 병아리가
/// 서로 반대쪽을 보고 새싹도 화면 반대편에 있다.
///
/// **제공자 버튼은 각 사의 브랜드 규격을 따른다.** 색·문구를 임의로 바꾸면
/// 스토어 심사나 제공자 검수에서 지적받는다.
///
/// 문구가 `~로 로그인`인 이유 — 애플이 `Apple로 로그인`·`Apple로 계속하기`·
/// `Apple로 가입` 셋만 허용한다. **셋 중 하나를 골라 카카오·네이버도
/// 맞춘다.** 애플만 다르게 두면 세 버튼이 어긋나 목록으로 읽히지 않는다.
///
/// **시안(`726:4924`·`726:4925`·`726:4926`)이 고른 문구는
/// `로그인`이다.** `계속하기`도 허용되지만 셋 다 애플이 허용하는 말이라 시안을 따른다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// 이 기기가 iOS인 척한다 — **시안 대조 전용**.
  ///
  /// 애플 로그인은 iOS에서만 뜨는데 위젯 시험은 macOS에서 돈다. 그대로 두면
  /// 버튼이 둘만 그려져 셋을 그린 시안과 자리가 통째로 어긋나, 정작 봐야 할
  /// 것이 묻힌다. 실제 화면 동작은 바꾸지 않는다.
  ///
  /// **버튼 유무와 장면 배치를 한 값이 함께 정한다.** 둘을 따로 열어 두면
  /// 시안에 없는 조합(얼굴 + 버튼 셋)을 시험이 만들어 낸다 — 그 조합이 바로
  /// 부리가 버튼 사이로 삐져나오던 화면이다.
  @visibleForTesting
  static bool? debugPretendIos;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// 버튼 사이 간격 12 — 시안 실측 (카카오 y=545, 네이버 y=623, 높이 66).
  static const _buttonGap = 12.0;

  /// 좌우 여백 16 · 하단 85 — 시안 실측 (버튼 x=16 w=360, 마지막 버튼 하단 767).
  ///
  /// 다른 화면의 `screenH`(24)와 다르다. 제공자 버튼만 시안이 더 넓게 잡았다.
  static const _sideInset = 16.0;
  static const _bottomInset = 85.0;

  /// 진행 중인 제공자. 중복 탭과 다른 버튼 동시 탭을 막는다.
  OAuthProvider? _pending;

  /// 실패 안내. 에러 코드를 함께 보여줘 제보를 추적할 수 있게 한다.

  /// 지난번에 성공한 로그인 수단. 없으면 처음 오는 사용자다.
  OAuthProvider? _lastProvider;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(loginControllerProvider).lastLoginProviderName();
    if (saved != null) {
      _lastProvider = OAuthProvider.values
          .where((p) => p.name == saved)
          .firstOrNull;
    }
  }

  Future<void> _signIn(OAuthProvider provider) async {
    // SDK await 뒤에는 context 를 쓰지 않으려고 문구 묶음을 먼저 잡는다.
    final l10n = context.l10n;
    setState(() => _pending = provider);

    final result = await ref.read(loginControllerProvider).signIn(provider);

    if (!mounted) return;

    // 로그인에 성공했으면 이전 세션의 이룸이 상태를 버린다. 회원 정보
    // 캐시가 남아 있으면 다른 계정의 이룸이 목록으로 고른 이룸이를 정해 버린다.
    if (const {
      AuthOutcome.consentRequired,
      AuthOutcome.onboarding,
      AuthOutcome.home,
    }.contains(result.outcome)) {
      await ref.read(loginControllerProvider).resetPreviousAccount();
      if (!mounted) return;
    }

    switch (result.outcome) {
      case AuthOutcome.consentRequired:
        // 약관 동의 없이는 서비스를 쓸 수 없다. 아이 정보를 받기 전에 먼저 받는다.
        _forgetPreviousChild();
        context.go(Routes.consent);
      case AuthOutcome.onboarding:
        _forgetPreviousChild();
        // 약관은 마쳤지만 이룸이 정보가 없는 계정이다. 보호자로 가다 멈춘 사람만이 아니라 **이룸이를 골랐던
        // 사람**(연결한 뒤 로그아웃)도 여기 온다. 이름 입력으로 곧장 보내면 이룸이를 다시 고를 길이 없다.
        // 약관 다음과 같은 자리(역할 선택)에서 다시 묻는다.
        context.go(Routes.roleSelect);
      case AuthOutcome.home:
        // 이미 아이 정보를 채운 계정이다. 온보딩을 건너뛰고 홈으로 보낸다.
        if (!mounted) return;
        final hasPin = await ref.read(loginControllerProvider).hasPin();
        if (!mounted) return;
        // 방금 인증한 보호자만 이 휴대폰 잠금을 새로 만들 수 있다.
        context.go(
          hasPin ? Routes.guardian : '${Routes.guardianPinChange}?from=login',
        );
      case AuthOutcome.cancelled:
        // 사용자가 스스로 닫았다. 아무것도 띄우지 않는다.
        break;
      // **서버 문구를 그대로 띄우는 것이 기본이다.** 서버 문구는 이미 사용자용으로
      // 쓰여 있고, 앱이 다시 쓰면 서버에서 고쳐도 앱은 옛 문구를 보여준다.
      // 아래 기본 문구는 서버가 아무 말도 주지 않았을 때만 나선다.
      case AuthOutcome.emailConflict:
        await _alert(
          result,
          title: l10n.loginDuplicateTitle,
          fallback: l10n.loginDuplicateFallback,
          fallbackCode: 'E-DUP',
        );
      case AuthOutcome.offline:
        await _alert(
          result,
          title: l10n.loginOfflineTitle,
          fallback: l10n.loginOfflineFallback,
          fallbackCode: 'E-NET',
        );
      // 사용자에게는 넷 다 같은 말이다. **코드만 다르다** — 제보를 받았을 때
      // 어디서 터졌는지 가릴 유일한 단서다.
      case AuthOutcome.failedSdk:
        await _alert(
          result,
          title: l10n.loginFailedTitle,
          fallback: l10n.loginFailedFallback,
          fallbackCode: 'E-AUTH-SDK',
        );
      case AuthOutcome.failedToken:
        await _alert(
          result,
          title: l10n.loginFailedTitle,
          fallback: l10n.loginFailedFallback,
          fallbackCode: 'E-AUTH-TOKEN',
        );
      case AuthOutcome.failedApi:
        await _alert(
          result,
          title: l10n.loginFailedTitle,
          fallback: l10n.loginFailedFallback,
          fallbackCode: 'E-AUTH-API',
        );
      case AuthOutcome.failed:
        await _alert(
          result,
          title: l10n.loginFailedTitle,
          fallback: l10n.loginFailedFallback,
          fallbackCode: 'E-AUTH',
        );
    }

    if (mounted) setState(() => _pending = null);
  }

  /// 실패를 팝업으로 알린다.
  ///
  /// **버튼 위 글자로 두지 않는다.** 배경이 그림이라 대비가 약해 눌린 버튼에
  /// 가려지고, 글자가 생기면서 버튼 묶음이 위로 밀려 누르려던 자리가 움직인다.
  /// 팝업은 앱 공통 [showElumDialog]를 그대로 쓴다 — 화면마다 새로 그리지
  /// 않는다는 결정을 따른다.
  ///
  /// **에러 코드는 그대로 노출한다.** 사용자에게는 뜻이 없지만, 제보를 받았을 때
  /// 어디서 터졌는지 가릴 유일한 단서다.
  /// 실패를 팝업으로 알린다 — **앱 공통 통로 하나만 쓴다**.
  ///
  /// 문구도 식별자도 [showFailure] 가 정한다. 서버가 이유를 줬으면 그 문구가
  /// [fallback] 을 이기고, 아무것도 없을 때만 [fallbackCode] 가 붙는다.
  Future<void> _alert(
    AuthResult result, {
    required String title,
    required String fallback,
    required String fallbackCode,
  }) {
    return showFailure(
      context,
      result.failure,
      title: title,
      fallback: fallback,
      fallbackCode: fallbackCode,
    );
  }

  /// 이전 계정의 아이 정보를 화면에서도 잊는다.
  ///
  /// 저장소는 [AuthRepository]가 이미 비웠지만, provider는 앱이 켜질 때 읽어 둔 값을
  /// 메모리에 들고 있다. 비우지 않으면 이름 입력칸에 남의 이름이 그대로 남는다.
  void _forgetPreviousChild() {
    ref.read(loginControllerProvider).forgetPreviousChild();
  }

  /// 이 기기가 iOS인가 — **애플 버튼과 장면 배치가 같이 갈린다.**
  bool get _isIos => LoginScreen.debugPretendIos ?? Platform.isIOS;

  /// 애플 버튼을 그리는가 — iOS 에서만 뜬다 (심사 요건).
  bool get _showApple => _isIos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LoginScene(
        layout: _isIos ? LoginSceneLayout.ios : LoginSceneLayout.android,
        // 버전은 버튼 묶음과 따로 얹는다 — 버튼 배치를 건드리지 않는다.
        overlay: Stack(
          children: [_buttons(context), const LoginVersionCorner()],
        ),
      ),
    );
  }

  /// 제공자 버튼 묶음. 시작 화면의 CTA가 있던 자리(화면 하단)에 얹는다.
  ///
  /// 그림 위에 겹쳐 놓기 때문에 하단 페이드(`splashFade`, y=675~852) 위로 올라온다.
  /// 셋으로 줄면서 페이드 영역 안에 거의 들어온다.
  Widget _buttons(BuildContext context) {
    final isBusy = _pending != null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        // 시안 그대로 — 카카오 y=545 · 네이버 y=623 · Apple y=701, 높이 66.
        // 마지막 버튼 하단이 767이므로 아래 여백은 852 − 767 = 85다.
        padding: EdgeInsets.fromLTRB(
          _sideInset.w,
          0,
          _sideInset.w,
          _bottomInset.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoginLastUsedSlot(
              show: _lastProvider == OAuthProvider.kakao,
              child: LoginProviderButton(
                label: _pending == OAuthProvider.kakao
                    ? context.l10n.loginConnecting
                    : context.l10n.loginKakaoButton,
                iconAsset: AppAssets.loginKakao,
                backgroundColor: context.colors.loginKakaoBg,
                labelColor: context.colors.loginKakaoLabel,
                onTap: isBusy ? null : () => _signIn(OAuthProvider.kakao),
              ),
            ),
            SizedBox(height: _buttonGap.h),

            LoginLastUsedSlot(
              show: _lastProvider == OAuthProvider.naver,
              child: LoginProviderButton(
                label: _pending == OAuthProvider.naver
                    ? context.l10n.loginConnecting
                    : context.l10n.loginNaverButton,
                iconAsset: AppAssets.loginNaver,
                backgroundColor: context.colors.loginNaverBg,
                labelColor: context.colors.loginNaverLabel,
                onTap: isBusy ? null : () => _signIn(OAuthProvider.naver),
              ),
            ),

            // 구글 버튼은 시안에서 빠졌다. `OAuthProvider.google`은
            // **지우지 않았다** — 저장소에 남은 `lastLoginProvider`가 'google'일
            // 때 파싱이 깨지면 안 되고, 서버 행의 provider 값도 그대로 산다.

            // 애플 로그인은 iOS에서만 노출한다.
            // 안드로이드에서 쓰려면 애플 개발자 콘솔에 Services ID를 따로 만들어야 하는데
            // 아직 없다. 버튼만 띄우면 눌러도 실패한다.
            //
            // 반대로 iOS에서는 빼면 안 된다 — 다른 소셜 로그인을 제공하는 앱은
            // 애플 로그인도 제공해야 앱스토어 심사를 통과한다.
            if (_showApple) ...[
              SizedBox(height: _buttonGap.h),

              // ⚠️ 규격 위젯(`SignInWithAppleButton`) 대신 직접 그린다.
              // 시안이 세 버튼을 같은 규격(360×66 · r18 · 로고 x=64)으로 그렸고,
              // 규격 위젯은 그 정렬을 맞출 수 없다.
              //
              // 애플이 요구하는 것을 전부 지킨다 — **검정 배경 · 흰 사과 심볼 ·
              // 최소 높이 · 승인 문구**. 문구는 `Apple로 로그인`·`Apple로 계속하기`·
              // `Apple로 가입` 셋만 허용되므로 **임의로 바꾸지 않는다**.
              LoginLastUsedSlot(
                show: _lastProvider == OAuthProvider.apple,
                child: LoginProviderButton(
                  label: _pending == OAuthProvider.apple
                      ? context.l10n.loginConnecting
                      : context.l10n.loginAppleButton,
                  iconAsset: AppAssets.loginApple,
                  backgroundColor: context.colors.loginAppleBg,
                  labelColor: context.colors.loginAppleLabel,
                  onTap: isBusy ? null : () => _signIn(OAuthProvider.apple),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
