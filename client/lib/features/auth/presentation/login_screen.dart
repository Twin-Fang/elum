import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/app_pressable.dart';
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
              '처음 쓰신 방법으로 로그인해주세요 (E-DUP)';
        });
      case AuthOutcome.offline:
        setState(() {
          _errorMessage = '인터넷 연결을 확인하고 다시 해주세요 (E-NET)';
        });
      case AuthOutcome.failed:
        setState(() {
          _errorMessage = '로그인하지 못했어요. 잠시 후 다시 해주세요 (E-AUTH)';
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
  /// 셋으로 줄면서(이슈 #230) 페이드 영역 안에 거의 들어온다.
  Widget _buttons(BuildContext context) {
    final isBusy = _pending != null;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        // 시안 그대로 — 카카오 y=545 · 네이버 y=623 · Apple y=701, 높이 66.
        // 마지막 버튼 하단이 767이므로 아래 여백은 852 − 767 = 85다.
        padding: EdgeInsets.fromLTRB(_sideInset.w, 0, _sideInset.w, _bottomInset.h),
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
            _ProviderButton(
              label: _pending == OAuthProvider.kakao ? '연결하고 있어요' : '카카오로 시작하기',
              iconAsset: AppAssets.loginKakao,
              backgroundColor: context.colors.loginKakaoBg,
              labelColor: context.colors.loginKakaoLabel,
              onTap: isBusy ? null : () => _signIn(OAuthProvider.kakao),
            ),
            SizedBox(height: _buttonGap.h),

            if (_lastProvider == OAuthProvider.naver) const _LastUsedHint(),
            _ProviderButton(
              label: _pending == OAuthProvider.naver ? '연결 중...' : '네이버로 시작하기',
              iconAsset: AppAssets.loginNaver,
              backgroundColor: context.colors.loginNaverBg,
              labelColor: context.colors.loginNaverLabel,
              onTap: isBusy ? null : () => _signIn(OAuthProvider.naver),
            ),

            // 구글 버튼은 시안에서 빠졌다 (이슈 #230). `OAuthProvider.google`은
            // **지우지 않았다** — 저장소에 남은 `lastLoginProvider`가 'google'일
            // 때 파싱이 깨지면 안 되고, 서버 행의 provider 값도 그대로 산다.

            // 애플 로그인은 iOS에서만 노출한다.
            // 안드로이드에서 쓰려면 애플 개발자 콘솔에 Services ID를 따로 만들어야 하는데
            // 아직 없다. 버튼만 띄우면 눌러도 실패한다.
            //
            // 반대로 iOS에서는 빼면 안 된다 — 다른 소셜 로그인을 제공하는 앱은
            // 애플 로그인도 제공해야 앱스토어 심사를 통과한다.
            if (Platform.isIOS) ...[
              SizedBox(height: _buttonGap.h),
              if (_lastProvider == OAuthProvider.apple) const _LastUsedHint(),
              // ⚠️ 규격 위젯(`SignInWithAppleButton`)에서 직접 그리기로 바꿨다.
              // 시안이 세 버튼을 같은 규격(360×66 · r18 · 로고 x=64)으로 그렸고,
              // 규격 위젯은 그 정렬을 맞출 수 없기 때문이다.
              //
              // 애플이 요구하는 것은 지켰다 — **검정 배경 · 흰 사과 심볼 ·
              // 최소 높이**. 다만 문구 `Apple로 시작하기`는 애플이 승인한 세 가지
              // (`Apple로 로그인`·`Apple로 계속하기`·`Apple로 가입`)에 없다.
              // 심사에서 지적받을 수 있어 이슈 #230에 남겼다.
              _ProviderButton(
                label: _pending == OAuthProvider.apple ? '연결 중...' : 'Apple로 시작하기',
                iconAsset: AppAssets.loginApple,
                backgroundColor: context.colors.loginAppleBg,
                labelColor: context.colors.loginAppleLabel,
                onTap: isBusy ? null : () => _signIn(OAuthProvider.apple),
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
/// 로그인 수단이 여럿이면 무엇을 썼는지 잊는다. 다른 것으로 들어오면 별개 계정이
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

/// 제공자 버튼 (360×66 · r18). Figma `로그인`(238:1808) 실측.
///
/// **로고는 왼쪽 64에 고정하고 문구는 버튼 가운데에 둔다.** 로고를 문구 바로
/// 앞에 붙이면 제공자마다 문구 길이가 달라 로고가 들쭉날쭉해진다. 세 개가
/// 한 줄로 서야 목록으로 읽힌다.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.iconAsset,
    required this.backgroundColor,
    required this.labelColor,
    required this.onTap,
  });

  final String label;

  /// 제공자 로고. 색이 SVG 안에 박혀 있어 여기서 덧칠하지 않는다.
  final String iconAsset;

  final Color backgroundColor;
  final Color labelColor;
  final VoidCallback? onTap;

  /// 로고 22×22, 왼쪽에서 64 (시안 실측). 세로는 버튼 가운데다.
  static const _iconSize = 22.0;
  static const _iconLeft = 64.0;

  @override
  Widget build(BuildContext context) {
    final space = context.space;

    return AppPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: space.buttonH.h,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(space.buttonRadius.r),
          boxShadow: [
            BoxShadow(
              color: context.colors.loginButtonShadow,
              offset: Offset(4.w, 4.h),
              blurRadius: 6.r,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              label,
              style: context.typo.loginProvider.copyWith(color: labelColor),
            ),
            Positioned(
              left: _iconLeft.w,
              child: SvgPicture.asset(
                iconAsset,
                width: _iconSize.w,
                height: _iconSize.w,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
