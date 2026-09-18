import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
import '../../../core/widgets/elum_button.dart';
import '../../../core/widgets/splash_scene.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/auth_repository.dart';
import '../data/oauth_sdk.dart';

/// 로그인 화면. 온보딩 맨 앞에 선다.
///
/// 계정이 먼저 생기고 그 안에 당사자 프로필을 만드는 서버 구조와 순서를 맞췄다.
/// 재설치한 사용자는 로그인만 하면 아이 정보가 서버에서 되살아난다.
///
/// **화면 그림은 시작 화면과 같은 [SplashScene]을 그대로 쓴다** (이슈 #207).
/// `시작하기` 버튼이 있던 자리에 제공자 버튼을 얹는다. 시작 화면에서 넘어오자마자
/// 배경이 통째로 바뀌면 다른 앱으로 튄 것처럼 보인다.
///
/// **제공자 버튼은 각 사의 브랜드 규격을 따른다.** 색·문구를 임의로 바꾸면
/// 스토어 심사나 제공자 검수에서 지적받는다.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// 버튼 사이 간격 18 — 온보딩 목표 칩의 리듬(칩 y좌표 차 86 − 높이 68)을 따른다.
  /// 같은 흐름 안에서 목록 간격이 화면마다 다르면 눈에 띈다.
  static const _buttonGap = 18.0;

  /// 진행 중인 제공자. 중복 탭과 다른 버튼 동시 탭을 막는다.
  OAuthProvider? _pending;

  /// 실패 안내. 에러 코드를 함께 보여줘 제보를 추적할 수 있게 한다.
  String? _errorMessage;

  /// 지난번에 성공한 로그인 수단. 없으면 처음 오는 사용자다.
  OAuthProvider? _lastProvider;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(localStorageProvider).lastLoginProvider;
    if (saved != null) {
      _lastProvider = OAuthProvider.values
          .where((p) => p.name == saved)
          .firstOrNull;
    }
  }

  Future<void> _signIn(OAuthProvider provider) async {
    setState(() {
      _pending = provider;
      _errorMessage = null;
    });

    final outcome = await ref.read(authRepositoryProvider).signInWith(provider);

    if (!mounted) return;

    switch (outcome) {
      case AuthOutcome.consentRequired:
        // 약관 동의 없이는 서비스를 쓸 수 없다. 아이 정보를 받기 전에 먼저 받는다.
        _forgetPreviousChild();
        context.go(Routes.consent);
      case AuthOutcome.onboarding:
        _forgetPreviousChild();
        context.go(Routes.onboardingName);
      case AuthOutcome.home:
        // 이미 아이 정보를 채운 계정이다. 온보딩을 건너뛰고 홈으로 보낸다.
        final nickname = ref.read(localStorageProvider).nickname ?? '';
        await ref.read(onboardingProvider.notifier).restoreCompleted(nickname);
        if (!mounted) return;
        context.go(Routes.guardian);
      case AuthOutcome.cancelled:
        // 사용자가 스스로 닫았다. 아무것도 띄우지 않는다.
        break;
      case AuthOutcome.emailConflict:
        setState(() {
          _errorMessage = '이미 다른 방법으로 가입된 계정이에요.\n'
              '처음 가입할 때 쓰신 방법으로 로그인해주세요. (E-DUP)';
        });
      case AuthOutcome.offline:
        setState(() {
          _errorMessage = '인터넷 연결을 확인하고 다시 눌러주세요. (E-NET)';
        });
      case AuthOutcome.failed:
        setState(() {
          _errorMessage = '로그인하지 못했어요. 잠시 후 다시 시도해주세요. (E-AUTH)';
        });
    }

    if (mounted) setState(() => _pending = null);
  }

  /// 이전 계정의 아이 정보를 화면에서도 잊는다.
  ///
  /// 저장소는 [AuthRepository]가 이미 비웠지만, provider는 앱이 켜질 때 읽어 둔 값을
  /// 메모리에 들고 있다. 비우지 않으면 이름 입력칸에 남의 이름이 그대로 남는다 (이슈 #177).
  void _forgetPreviousChild() {
    ref.invalidate(onboardingProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SplashScene(overlay: _buttons(context)),
    );
  }

  /// 제공자 버튼 묶음. 시작 화면의 CTA가 있던 자리(화면 하단)에 얹는다.
  ///
  /// 그림 위에 겹쳐 놓기 때문에 하단 페이드(`splashFade`, y=675~852) 위로 올라온다.
  /// 버튼이 넷이면 페이드 영역만으로는 모자라 병아리 위까지 올라오는데, 페이드가
  /// 그 경계를 흐려주므로 읽는 데 지장은 없다.
  Widget _buttons(BuildContext context) {
    final isBusy = _pending != null;
    final space = context.space;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        // 아래 여백 132 = 852(디자인 높이) − 720(버튼 하단).
        //
        // 아래로는 y=756의 신뢰 배지, 위로는 y=573의 언덕 위 실루엣이 경계다.
        // 112(배지 바로 위)로 두면 실루엣 머리가 카카오·네이버 버튼 **틈**으로
        // 삐져나와 눈처럼 보인다. 20 올려 실루엣이 버튼 뒤로 완전히 들어가게 했다.
        padding: EdgeInsets.fromLTRB(space.screenH.w, 0, space.screenH.w, 132.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                // 아동도 볼 수 있는 화면이라 빨강·경고 아이콘을 쓰지 않는다
                style: context.typo.body.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              SizedBox(height: context.space.md),
            ],

            if (_lastProvider == OAuthProvider.kakao) const _LastUsedHint(),
            ElumButton(
              label: _pending == OAuthProvider.kakao ? '연결 중...' : '카카오로 시작하기',
              backgroundColor: context.colors.loginKakaoBg,
              labelColor: context.colors.loginKakaoLabel,
              onPressed: isBusy ? null : () => _signIn(OAuthProvider.kakao),
            ),
            SizedBox(height: _buttonGap.h),

            if (_lastProvider == OAuthProvider.naver) const _LastUsedHint(),
            ElumButton(
              label: _pending == OAuthProvider.naver ? '연결 중...' : '네이버로 시작하기',
              backgroundColor: context.colors.loginNaverBg,
              labelColor: context.colors.loginNaverLabel,
              onPressed: isBusy ? null : () => _signIn(OAuthProvider.naver),
            ),
            SizedBox(height: _buttonGap.h),

            if (_lastProvider == OAuthProvider.google) const _LastUsedHint(),
            // 구글만 테두리가 필요해 따로 그린다. 크기·모서리는 ElumButton과 같은
            // 토큰을 쓴다 — 버튼마다 규격이 다르면 화면이 어수선해진다.
            _OutlinedProviderButton(
              label: _pending == OAuthProvider.google ? '연결 중...' : 'Google로 시작하기',
              onTap: isBusy ? null : () => _signIn(OAuthProvider.google),
            ),

            // 애플 로그인은 iOS에서만 노출한다.
            // 안드로이드에서 쓰려면 애플 개발자 콘솔에 Services ID를 따로 만들어야 하는데
            // 아직 없다. 버튼만 띄우면 눌러도 실패한다.
            //
            // 반대로 iOS에서는 빼면 안 된다 — 다른 소셜 로그인을 제공하는 앱은
            // 애플 로그인도 제공해야 앱스토어 심사를 통과한다.
            if (Platform.isIOS) ...[
              SizedBox(height: _buttonGap.h),
              if (_lastProvider == OAuthProvider.apple) const _LastUsedHint(),
              Opacity(
                opacity: isBusy && _pending != OAuthProvider.apple ? 0.5 : 1,
                // 애플 버튼은 규격 위젯을 그대로 쓴다. 색·문구·로고를 직접 그리면
                // 애플 심사 가이드라인 위반이다. 크기만 앱 버튼에 맞춘다.
                child: SignInWithAppleButton(
                  text: _pending == OAuthProvider.apple ? '연결 중...' : 'Apple로 시작하기',
                  height: context.space.buttonH.h,
                  borderRadius: BorderRadius.circular(context.space.buttonRadius.r),
                  onPressed: isBusy ? () {} : () => _signIn(OAuthProvider.apple),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "지난번에 이걸로" 안내.
///
/// 소셜 로그인이 넷이면 무엇을 썼는지 잊는다. 다른 것으로 들어오면 별개 계정이
/// 생겨 아이 정보가 사라진 것처럼 보인다. 그 사고를 막는 장치다.
class _LastUsedHint extends StatelessWidget {
  const _LastUsedHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.space.xs.h / 2),
      child: Text(
        '지난번에 이걸로 로그인했어요',
        textAlign: TextAlign.center,
        style: context.typo.caption.copyWith(
          color: context.colors.textSecondary,
        ),
      ),
    );
  }
}

/// 테두리가 있는 제공자 버튼. 구글만 흰 배경이라 경계선이 필요하다.
///
/// 크기·모서리·타이포는 [ElumButton]과 같은 토큰을 쓴다. 버튼마다 규격이 다르면
/// 한 화면에 놓였을 때 어긋나 보인다.
class _OutlinedProviderButton extends StatelessWidget {
  const _OutlinedProviderButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: space.buttonH.h,
        decoration: BoxDecoration(
          color: colors.loginGoogleBg,
          borderRadius: BorderRadius.circular(space.buttonRadius.r),
          border: Border.all(color: colors.loginGoogleBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.typo.button.copyWith(color: colors.loginGoogleLabel),
        ),
      ),
    );
  }
}
