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
import '../../../core/widgets/elum_dialog.dart';
import '../../../core/widgets/show_failure.dart';
import '../../../core/widgets/login_scene.dart';
import '../../onboarding/application/onboarding_notifier.dart';
import '../data/auth_repository.dart';
import '../data/oauth_sdk.dart';

/// 로그인 화면. 온보딩 맨 앞에 선다.
///
/// 계정이 먼저 생기고 그 안에 당사자 프로필을 만드는 서버 구조와 순서를 맞췄다.
/// 재설치한 사용자는 로그인만 하면 아이 정보가 서버에서 되살아난다.
///
/// **화면 그림은 [LoginScene]이 그리고, 배치는 플랫폼마다 다르다** (이슈 #338).
/// 시안이 `로그인_iOS`(238:1808)와 `로그인_AOS`(1022:4333) 둘로 나와, 병아리가
/// 서로 반대쪽을 보고 새싹도 화면 반대편에 있다.
///
/// **제공자 버튼은 각 사의 브랜드 규격을 따른다.** 색·문구를 임의로 바꾸면
/// 스토어 심사나 제공자 검수에서 지적받는다.
///
/// 문구가 `~로 로그인`인 이유 — 애플이 `Apple로 로그인`·`Apple로 계속하기`·
/// `Apple로 가입` 셋만 허용한다 (이슈 #237). **셋 중 하나를 골라 카카오·네이버도
/// 맞춘다.** 애플만 다르게 두면 세 버튼이 어긋나 목록으로 읽히지 않는다.
///
/// 한때 `계속하기`를 골랐는데 **시안(`726:4924`·`726:4925`·`726:4926`)이 고른 것은
/// `로그인`이다.** 셋 다 애플이 허용하는 말이라 시안을 따른다 (#297).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  /// 이 기기가 iOS인 척한다 — **시안 대조 전용**.
  ///
  /// 애플 로그인은 iOS에서만 뜨는데 위젯 시험은 macOS에서 돈다. 그대로 두면
  /// 버튼이 둘만 그려져 셋을 그린 시안과 자리가 통째로 어긋나, 정작 봐야 할
  /// 것이 묻힌다 (#297). 실제 화면 동작은 바꾸지 않는다.
  ///
  /// **버튼 유무와 장면 배치를 한 값이 함께 정한다.** 둘을 따로 열어 두면
  /// 시안에 없는 조합(얼굴 + 버튼 셋)을 시험이 만들어 낸다 — 그 조합이 바로
  /// 부리가 버튼 사이로 삐져나오던 화면이다 (#338).
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
    final saved = ref.read(localStorageProvider).lastLoginProvider;
    if (saved != null) {
      _lastProvider = OAuthProvider.values
          .where((p) => p.name == saved)
          .firstOrNull;
    }
  }

  Future<void> _signIn(OAuthProvider provider) async {
    setState(() => _pending = provider);

    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInWith(provider);

    if (!mounted) return;

    switch (result.outcome) {
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
      // **서버 문구를 그대로 띄우는 것이 기본이다.** 서버 문구는 이미 사용자용으로
      // 쓰여 있고, 앱이 다시 쓰면 서버에서 고쳐도 앱은 옛 문구를 보여준다 (#347).
      // 아래 기본 문구는 서버가 아무 말도 주지 않았을 때만 나선다 (#352).
      case AuthOutcome.emailConflict:
        await _alert(
          result,
          title: '이미 가입된 계정이에요',
          fallback: '처음 쓰신 방법으로 로그인해주세요',
          fallbackCode: 'E-DUP',
        );
      case AuthOutcome.offline:
        await _alert(
          result,
          title: '인터넷 연결을 확인해주세요',
          fallback: '연결한 뒤 다시 해주세요',
          fallbackCode: 'E-NET',
        );
      // 사용자에게는 넷 다 같은 말이다. **코드만 다르다** — 제보를 받았을 때
      // 어디서 터졌는지 가릴 유일한 단서다 (#346).
      case AuthOutcome.failedSdk:
        await _alert(
          result,
          title: '로그인하지 못했어요',
          fallback: '잠시 후 다시 해주세요',
          fallbackCode: 'E-AUTH-SDK',
        );
      case AuthOutcome.failedToken:
        await _alert(
          result,
          title: '로그인하지 못했어요',
          fallback: '잠시 후 다시 해주세요',
          fallbackCode: 'E-AUTH-TOKEN',
        );
      case AuthOutcome.failedApi:
        await _alert(
          result,
          title: '로그인하지 못했어요',
          fallback: '잠시 후 다시 해주세요',
          fallbackCode: 'E-AUTH-API',
        );
      case AuthOutcome.failed:
        await _alert(
          result,
          title: '로그인하지 못했어요',
          fallback: '잠시 후 다시 해주세요',
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
  /// 않는다는 결정(#232)을 따른다 (#346).
  ///
  /// **에러 코드는 그대로 노출한다.** 사용자에게는 뜻이 없지만, 제보를 받았을 때
  /// 어디서 터졌는지 가릴 유일한 단서다.
  /// 실패를 팝업으로 알린다 — **앱 공통 통로 하나만 쓴다** (#352).
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
  /// 메모리에 들고 있다. 비우지 않으면 이름 입력칸에 남의 이름이 그대로 남는다 (이슈 #177).
  void _forgetPreviousChild() {
    ref.invalidate(onboardingProvider);
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
        overlay: _buttons(context),
      ),
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
            _LastUsedSlot(
              show: _lastProvider == OAuthProvider.kakao,
              child: _ProviderButton(
              label: _pending == OAuthProvider.kakao ? '연결하고 있어요' : '카카오로 로그인',
              iconAsset: AppAssets.loginKakao,
              backgroundColor: context.colors.loginKakaoBg,
              labelColor: context.colors.loginKakaoLabel,
                onTap: isBusy ? null : () => _signIn(OAuthProvider.kakao),
              ),
            ),
            SizedBox(height: _buttonGap.h),

            _LastUsedSlot(
              show: _lastProvider == OAuthProvider.naver,
              child: _ProviderButton(
              label: _pending == OAuthProvider.naver ? '연결하고 있어요' : '네이버로 로그인',
              iconAsset: AppAssets.loginNaver,
              backgroundColor: context.colors.loginNaverBg,
              labelColor: context.colors.loginNaverLabel,
                onTap: isBusy ? null : () => _signIn(OAuthProvider.naver),
              ),
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
            if (_showApple) ...[
              SizedBox(height: _buttonGap.h),

              // ⚠️ 규격 위젯(`SignInWithAppleButton`)에서 직접 그리기로 바꿨다.
              // 시안이 세 버튼을 같은 규격(360×66 · r18 · 로고 x=64)으로 그렸고,
              // 규격 위젯은 그 정렬을 맞출 수 없기 때문이다.
              //
              // 애플이 요구하는 것을 전부 지킨다 — **검정 배경 · 흰 사과 심볼 ·
              // 최소 높이 · 승인 문구**. 문구는 `Apple로 로그인`·`Apple로 계속하기`·
              // `Apple로 가입` 셋만 허용되므로 **임의로 바꾸지 않는다** (이슈 #237).
              _LastUsedSlot(
                show: _lastProvider == OAuthProvider.apple,
                child: _ProviderButton(
                  label: _pending == OAuthProvider.apple ? '연결하고 있어요' : 'Apple로 로그인',
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

/// "지난번에 이걸로" 안내.
///
/// 로그인 수단이 여럿이면 무엇을 썼는지 잊는다. 다른 것으로 들어오면 별개 계정이
/// 생겨 아이 정보가 사라진 것처럼 보인다. 그 사고를 막는 장치다.
/// `지난번에 이걸로 로그인했어요` — 마지막으로 쓴 제공자 위에 붙는다.
///
/// **글자 뒤에 옅은 알약을 깐다.** 이 문구는 병아리 그림 위에 얹히는데 회색
/// 글자라 그냥 두면 묻힌다. 안드로이드에서는 얼굴을 그리므로(#297) 부리와
/// 정확히 겹쳐 `이걸로` 가 읽히지 않았다 — 부리 y614~638, 문구 y623~633
/// (이슈 #337). iOS 도 노란 몸통 위라 대비가 좋지 않아 **양쪽 다** 깐다.
///
/// 반투명이라 뒤 그림이 비쳐 덧댄 것처럼 보이지 않는다.
/// 제공자 버튼 위에 `최근 로그인` 알약을 얹는 자리.
///
/// Figma `로그인_iOS`(238:1808) 실측 — 알약 **91×28 · r20**, 버튼 **우측에서 16**,
/// 버튼 상단에서 **위로 10** 겹친다. 배경은 `#FFFADC` 투명도 50%이라 아래 버튼
/// 색이 비쳐, 세 제공자에서 각각 다른 색으로 보인다.
///
/// **줄을 따로 차지하지 않는다.** 이전 구현은 버튼 위에 한 줄을 깔아, 최근 로그인이
/// 있을 때만 버튼 묶음이 통째로 밀렸다 — 누르려던 자리가 움직인다. 버튼 간격이
/// 12라 위로 10 겹쳐도 레이아웃은 그대로다 (#346).
///
/// [show]가 거짓이면 버튼만 그대로 내보낸다 — `Stack`을 세우지 않는다.
class _LastUsedSlot extends StatelessWidget {
  const _LastUsedSlot({required this.show, required this.child});

  final bool show;
  final Widget child;

  /// 시안 실측 — 알약 91×28 · r20.
  static const _pillWidth = 91.0;
  static const _pillHeight = 28.0;
  static const _pillRadius = 20.0;

  /// 버튼 우측에서 16 · 버튼 위로 10.
  static const _right = 16.0;
  static const _top = 10.0;

  @override
  Widget build(BuildContext context) {
    if (!show) return child;

    return Stack(
      // 알약이 버튼 위로 삐져나온다. 자르면 시안과 달라진다.
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: _right.w,
          top: -_top.h,
          child: Container(
            width: _pillWidth.w,
            height: _pillHeight.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.colors.loginLastUsedBg,
              borderRadius: BorderRadius.circular(_pillRadius.r),
            ),
            child: Text(
              '최근 로그인',
              style: context.typo.lastLoginBadge.copyWith(
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ),
      ],
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
